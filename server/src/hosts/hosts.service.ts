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
