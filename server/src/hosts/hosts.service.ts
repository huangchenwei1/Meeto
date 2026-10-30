import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Invitation, User } from '@prisma/client';
import {
  ApplicationStatus,
  InvitationStatus,
  NotificationType,
  OrderStatus,
  PostOrigin,
  PostStatus,
  Role,
} from '../common/enums.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { assertVerified } from '../common/verification.util.js';
import { NotificationsService } from '../notifications/notifications.module.js';
import { OrderDto, toOrderDto } from '../orders/order.mapper.js';
import { PricingService } from '../pricing/pricing.service.js';
import { PrismaService } from '../prisma/prisma.service.js';

/// Directory card: activity credentials first, looks second. The client
/// renders completed activities and recent plan pitches as the headline.
export interface HostCardDto {
  user: PublicUser;
  completedActivities: number;
  recentProposals: string[];
}

/// Feed card for a host's activity pitch: the proposal is the product,
/// the host is the signature line. Fee display is resolved client-side
/// from the live pricing config (orders snapshot it at acceptance).
export interface ProposalDto {
  id: string;
  title: string;
  sceneTag: string;
  createdAt: Date;
  host: PublicUser;
  hostCompletedActivities: number;
}

export interface InvitationDto {
  id: string;
  sceneTag: string;
  note: string;
  status: string;
  from: PublicUser;
  host: PublicUser;
  postId: string;
  orderId: string;
  createdAt: Date;
}

type InvitationWithParties = Invitation & { from: User; host: User };

function parseScenes(json: string): string[] {
  try {
    const parsed: unknown = JSON.parse(json);
    return Array.isArray(parsed)
      ? parsed.filter((s): s is string => typeof s === 'string')
      : [];
  } catch {
    return [];
  }
}

@Injectable()
export class HostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pricingService: PricingService,
    private readonly notifications: NotificationsService,
  ) {}

  /// Host directory, best credentials first. [gender] is a viewer
  /// preference filter, same semantics as the feed filter.
  async directory(gender?: string): Promise<HostCardDto[]> {
    const hosts = await this.prisma.user.findMany({
      where: {
        role: Role.host,
        ...(gender ? { gender } : {}),
      },
      orderBy: { createdAt: 'asc' },
    });
    const cards = await Promise.all(hosts.map((h) => this.toHostCard(h)));
    cards.sort(
      (a, b) =>
        Number(b.user.isVerified) - Number(a.user.isVerified) ||
        b.completedActivities - a.completedActivities,
    );
    return cards;
  }

  async getHost(hostId: string): Promise<HostCardDto> {
    const host = await this.prisma.user.findUnique({ where: { id: hostId } });
    if (!host || host.role !== Role.host) {
      throw new NotFoundException('Host not found');
    }
    return this.toHostCard(host);
  }

  /// A host publishes an activity pitch to the user home feed. Scene
  /// validation mirrors [invite]: the pitch must be within the host's
  /// offered scenes because the invitation it attracts will be.
  async createProposal(
    caller: User,
    title: string,
    sceneTag: string,
  ): Promise<ProposalDto> {
    assertVerified(caller);
    if (caller.role !== Role.host) {
      throw new ForbiddenException('Only hosts can publish proposals');
    }
    const offered = parseScenes(caller.hostScenesJson);
    if (offered.length > 0 && !offered.includes(sceneTag)) {
      throw new ConflictException('SCENE_NOT_OFFERED');
    }
    const [proposal, completed] = await Promise.all([
      this.prisma.proposal.create({
        data: { hostId: caller.id, title: title.trim(), sceneTag },
        include: { host: true },
      }),
      this.prisma.order.count({
        where: { earnerId: caller.id, status: OrderStatus.completed },
      }),
    ]);
    return {
      id: proposal.id,
      title: proposal.title,
      sceneTag: proposal.sceneTag,
      createdAt: proposal.createdAt,
      host: toPublicUser(proposal.host),
      hostCompletedActivities: completed,
    };
  }

  /// The user home feed: newest pitches first. Completed-activity counts
  /// are batched so the feed stays one query per table.
  async proposalFeed(): Promise<ProposalDto[]> {
    const proposals = await this.prisma.proposal.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { host: true },
    });
    const hostIds = [...new Set(proposals.map((p) => p.hostId))];
    const counts = await this.prisma.order.groupBy({
      by: ['earnerId'],
      where: { earnerId: { in: hostIds }, status: OrderStatus.completed },
      _count: { _all: true },
    });
    const completedByHost = new Map(
      counts.map((c) => [c.earnerId, c._count._all]),
    );
    return proposals.map((p) => ({
      id: p.id,
      title: p.title,
      sceneTag: p.sceneTag,
      createdAt: p.createdAt,
      host: toPublicUser(p.host),
      hostCompletedActivities: completedByHost.get(p.hostId) ?? 0,
    }));
  }

  /// A user invites a host directly. The invitation carries the rough
  /// intent (scene + note); the concrete plan still comes from the host
  /// after payment, via the standard plan flow.
  async invite(
    caller: User,
    hostId: string,
    sceneTag: string,
    note: string,
  ): Promise<InvitationDto> {
    assertVerified(caller);
    if (caller.role === Role.host) {
      throw new ForbiddenException('Hosts cannot invite other hosts');
    }
    const host = await this.prisma.user.findUnique({ where: { id: hostId } });
    if (!host || host.role !== Role.host) {
      throw new NotFoundException('Host not found');
    }
    // Invitations are bound to the host's offered scenes (picked at
    // registration); hosts without a published list take any scene.
    const offered = parseScenes(host.hostScenesJson);
    if (offered.length > 0 && !offered.includes(sceneTag)) {
      throw new ConflictException('SCENE_NOT_OFFERED');
    }
    const pending = await this.prisma.invitation.findFirst({
      where: {
        fromUserId: caller.id,
        hostId,
        status: InvitationStatus.pending,
      },
    });
    if (pending) {
      throw new ConflictException('INVITE_ALREADY_PENDING');
    }
    const invitation = await this.prisma.invitation.create({
      data: { fromUserId: caller.id, hostId, sceneTag, note },
      include: { from: true, host: true },
    });
    await this.notifications.notify(this.prisma, {
      userId: hostId,
      type: NotificationType.inviteReceived,
      actorName: caller.name,
      actorAvatarUrl: caller.avatarUrl,
    });
    return HostsService.toInvitationDto(invitation);
  }

  /// Hosts see invitations they received; users see the ones they sent.
  async listMine(caller: User): Promise<InvitationDto[]> {
    const invitations = await this.prisma.invitation.findMany({
      where:
        caller.role === Role.host
          ? { hostId: caller.id }
          : { fromUserId: caller.id },
      include: { from: true, host: true },
      orderBy: { createdAt: 'desc' },
    });
    return invitations.map((i) => HostsService.toInvitationDto(i));
  }

  /// Accepting creates the whole order context in one transaction: a direct
  /// post (never shown in the open feed), a SELECTED application, and an
  /// order awaiting payment. Downstream (payment, plan, meet, settlement)
  /// is the standard order flow.
  async accept(caller: User, invitationId: string): Promise<OrderDto> {
    assertVerified(caller);
    const invitation = await this.findPendingForHost(caller, invitationId);
    const feeMinor = await this.pricingService.feeForScene(
      invitation.sceneTag,
    );
    const split = await this.pricingService.splitFee(feeMinor);
    const order = await this.prisma.$transaction(async (tx) => {
      const post = await tx.post.create({
        data: {
          authorId: invitation.fromUserId,
          sceneTag: invitation.sceneTag,
          title: invitation.note.trim() || invitation.sceneTag,
          description: invitation.note,
          status: PostStatus.pendingPayment,
          origin: PostOrigin.direct,
          feeMinor,
        },
      });
      await tx.application.create({
        data: {
          postId: post.id,
          applicantId: caller.id,
          status: ApplicationStatus.selected,
        },
      });
      const created = await tx.order.create({
        data: {
          postId: post.id,
          payerId: invitation.fromUserId,
          earnerId: caller.id,
          status: OrderStatus.awaitingPayment,
          feeMinor: split.feeMinor,
          commissionMinor: split.commissionMinor,
          netMinor: split.netMinor,
        },
        include: { payer: true, earner: true, post: true },
      });
      await tx.invitation.update({
        where: { id: invitation.id },
        data: {
          status: InvitationStatus.accepted,
          postId: post.id,
          orderId: created.id,
          respondedAt: new Date(),
        },
      });
      await this.notifications.notify(tx, {
        userId: invitation.fromUserId,
        type: NotificationType.inviteAccepted,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId: post.id,
        orderId: created.id,
      });
      return created;
    });
    return toOrderDto(order);
  }

  async decline(caller: User, invitationId: string): Promise<InvitationDto> {
    const invitation = await this.findPendingForHost(caller, invitationId);
    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.invitation.update({
        where: { id: invitation.id },
        data: {
          status: InvitationStatus.declined,
          respondedAt: new Date(),
        },
        include: { from: true, host: true },
      });
      await this.notifications.notify(tx, {
        userId: invitation.fromUserId,
        type: NotificationType.inviteDeclined,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
      });
      return row;
    });
    return HostsService.toInvitationDto(updated);
  }

  private async findPendingForHost(
    caller: User,
    invitationId: string,
  ): Promise<Invitation> {
    const invitation = await this.prisma.invitation.findUnique({
      where: { id: invitationId },
    });
    if (!invitation) {
      throw new NotFoundException('Invitation not found');
    }
    if (invitation.hostId !== caller.id) {
      throw new ForbiddenException('Only the invited host can respond');
    }
    if (invitation.status !== InvitationStatus.pending) {
      throw new ConflictException('Invitation already responded to');
    }
    return invitation;
  }

  private async toHostCard(host: User): Promise<HostCardDto> {
    const [completedActivities, applications] = await Promise.all([
      this.prisma.order.count({
        where: { earnerId: host.id, status: OrderStatus.completed },
      }),
      this.prisma.application.findMany({
        where: { applicantId: host.id, proposal: { not: '' } },
        orderBy: { createdAt: 'desc' },
        take: 3,
        select: { proposal: true },
      }),
    ]);
    return {
      user: toPublicUser(host),
      completedActivities,
      recentProposals: applications.map((a) => a.proposal),
    };
  }

  private static toInvitationDto(
    invitation: InvitationWithParties,
  ): InvitationDto {
    return {
      id: invitation.id,
      sceneTag: invitation.sceneTag,
      note: invitation.note,
      status: invitation.status,
      from: toPublicUser(invitation.from),
      host: toPublicUser(invitation.host),
      postId: invitation.postId,
      orderId: invitation.orderId,
      createdAt: invitation.createdAt,
    };
  }
}
