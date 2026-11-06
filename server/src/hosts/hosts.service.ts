import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Invitation, Proposal, User } from '@prisma/client';
import {
  ApplicationStatus,
  InvitationStatus,
  OrderStatus,
  PostOrigin,
  PostStatus,
  Role,
} from '../common/enums.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { assertVerified } from '../common/verification.util.js';
import { OrderDto, toOrderDto } from '../orders/order.mapper.js';
import { generateMeetCode } from '../common/meet-code.util.js';
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
/// the host is the signature line. The exact mirror of a demand post —
/// users invite on it the way hosts sign up on a post, and the host picks
/// one inviter to form the order.
export interface ProposalDto {
  id: string;
  title: string;
  description: string;
  sceneTag: string;
  imageUrl: string;
  area: string;
  timeSlot: string;
  /// The budget tier the host picked at publish time (minor units):
  /// invitations on this pitch lock to it.
  budgetMinor: number;
  /// OPEN | PENDING_PAYMENT | MATCHED | COMPLETED | CANCELLED, mirroring
  /// post statuses; only OPEN proposals take invitations.
  status: string;
  /// Pending invitations waiting for the host's pick.
  inviteCount: number;
  /// Whether the calling user has a pending invitation on this proposal.
  hasInvited: boolean;
  createdAt: Date;
  host: PublicUser;
  hostCompletedActivities: number;
}

/// One user's invitation on a proposal, shown to the proposal's host in
/// the candidate list (the mirror of ApplicationDto on the demand side).
export interface InvitationDto {
  id: string;
  proposalId: string;
  note: string;
  status: string;
  from: PublicUser;
  createdAt: Date;
}

type ProposalWithHost = Proposal & { host: User };
type InvitationWithFrom = Invitation & { from: User };

@Injectable()
export class HostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pricingService: PricingService,
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

  /// A host publishes an activity pitch to the hall. Any priced scene
  /// goes: what a host "offers" is whatever they actually pitch, not a
  /// list declared at registration.
  async createProposal(
    caller: User,
    title: string,
    description: string,
    sceneTag: string,
    imageUrl: string,
    area: string,
    timeSlot: string,
    budgetMinor?: number,
  ): Promise<ProposalDto> {
    assertVerified(caller);
    if (caller.role !== Role.host) {
      throw new ForbiddenException('Only hosts can publish proposals');
    }
    // Whoever launches the activity prices it: the host picks one of the
    // platform tiers, exactly like a poster pricing a demand post.
    const budget = await this.pricingService.resolveBudget(
      sceneTag,
      budgetMinor,
    );
    const proposal = await this.prisma.proposal.create({
      data: {
        hostId: caller.id,
        title: title.trim(),
        description: description.trim(),
        sceneTag,
        imageUrl,
        area,
        timeSlot,
        budgetMinor: budget,
      },
      include: { host: true },
    });
    return this.toProposalDto(proposal, caller.id);
  }

  /// The hall feed: open pitches only (matched ones left the market),
  /// newest first. ROLE-ISOLATED: users shop every host's pitches; a host
  /// sees only their own — same-side browsing is deliberately off (no
  /// peeking at competitors' copy and pricing). Per-proposal counts are
  /// batched so the feed stays a handful of queries, not one per card.
  async proposalFeed(caller: User): Promise<ProposalDto[]> {
    const proposals = await this.prisma.proposal.findMany({
      where: {
        status: PostStatus.open,
        ...(caller.role === Role.host ? { hostId: caller.id } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: { host: true },
    });
    const ids = proposals.map((p) => p.id);
    const hostIds = [...new Set(proposals.map((p) => p.hostId))];
    const [completedCounts, inviteCounts, mine] = await Promise.all([
      this.prisma.order.groupBy({
        by: ['earnerId'],
        where: { earnerId: { in: hostIds }, status: OrderStatus.completed },
        _count: { _all: true },
      }),
      this.prisma.invitation.groupBy({
        by: ['proposalId'],
        where: { proposalId: { in: ids }, status: InvitationStatus.pending },
        _count: { _all: true },
      }),
      this.prisma.invitation.findMany({
        where: {
          proposalId: { in: ids },
          fromUserId: caller.id,
          status: InvitationStatus.pending,
        },
        select: { proposalId: true },
      }),
    ]);
    const completedByHost = new Map(
      completedCounts.map((c) => [c.earnerId, c._count._all]),
    );
    const invitesByProposal = new Map(
      inviteCounts.map((c) => [c.proposalId, c._count._all]),
    );
    const invited = new Set(mine.map((i) => i.proposalId));
    return proposals.map((p) => ({
      id: p.id,
      title: p.title,
      description: p.description,
      sceneTag: p.sceneTag,
      imageUrl: p.imageUrl,
      area: p.area,
      timeSlot: p.timeSlot,
      budgetMinor: p.budgetMinor,
      status: p.status,
      inviteCount: invitesByProposal.get(p.id) ?? 0,
      hasInvited: invited.has(p.id),
      createdAt: p.createdAt,
      host: toPublicUser(p.host),
      hostCompletedActivities: completedByHost.get(p.hostId) ?? 0,
    }));
  }

  /// Full proposal detail, any viewer. The invite pool itself stays
  /// host-only (listInvites); everyone else just sees the count.
  async getProposal(caller: User, proposalId: string): Promise<ProposalDto> {
    const proposal = await this.findProposalOrThrow(proposalId);
    return this.toProposalDto(proposal, caller.id);
  }

  /// A user invites the host on a pitch — the mirror of a host signing up
  /// on a demand post. Free, non-binding, and several users can queue on
  /// the same proposal; the scene and the price are locked to the pitch.
  async invite(
    caller: User,
    proposalId: string,
    note: string,
  ): Promise<InvitationDto> {
    assertVerified(caller);
    if (caller.role === Role.host) {
      throw new ForbiddenException('Hosts cannot invite other hosts');
    }
    const proposal = await this.findProposalOrThrow(proposalId);
    if (proposal.status !== PostStatus.open) {
      throw new ConflictException('PROPOSAL_NOT_OPEN');
    }
    const pending = await this.prisma.invitation.findFirst({
      where: {
        proposalId,
        fromUserId: caller.id,
        status: InvitationStatus.pending,
      },
    });
    if (pending) {
      throw new ConflictException('INVITE_ALREADY_PENDING');
    }
    // Snapshot the pitch's tier now so platform repricing never changes a
    // pending invitation under anyone's feet.
    const budgetMinor =
      proposal.budgetMinor > 0
        ? proposal.budgetMinor
        : await this.pricingService.resolveBudget(proposal.sceneTag);
    const invitation = await this.prisma.invitation.create({
      data: {
        proposalId,
        fromUserId: caller.id,
        hostId: proposal.hostId,
        sceneTag: proposal.sceneTag,
        note,
        budgetMinor,
      },
      include: { from: true },
    });
    return HostsService.toInvitationDto(invitation);
  }

  /// The proposal's pending invite pool, host-only — the mirror of the
  /// poster-only candidate list on a demand post.
  async listInvites(
    caller: User,
    proposalId: string,
  ): Promise<InvitationDto[]> {
    const proposal = await this.findProposalOrThrow(proposalId);
    if (proposal.hostId !== caller.id) {
      throw new ForbiddenException('Only the host sees the invite pool');
    }
    const invitations = await this.prisma.invitation.findMany({
      where: { proposalId, status: InvitationStatus.pending },
      include: { from: true },
      orderBy: { createdAt: 'asc' },
    });
    return invitations.map((i) => HostsService.toInvitationDto(i));
  }

  /// The host picks one inviter. Creates the whole order context in one
  /// transaction: a direct post (never shown in the open feed) carrying
  /// the proposal link, a SELECTED application, and an order awaiting the
  /// inviter's payment. Downstream (payment, plan, meet code, settlement)
  /// is the standard order flow; the order lifecycle mirrors its status
  /// back onto the proposal through the post's proposalId.
  async select(
    caller: User,
    proposalId: string,
    invitationId: string,
    plan: {
      place: string;
      scheduledAt: string;
      durationMinutes: number;
      note: string;
    },
  ): Promise<OrderDto> {
    assertVerified(caller);
    const proposal = await this.findProposalOrThrow(proposalId);
    if (proposal.hostId !== caller.id) {
      throw new ForbiddenException('Only the host can select an inviter');
    }
    if (proposal.status !== PostStatus.open) {
      throw new ConflictException('Proposal is not open for selection');
    }
    const invitation = await this.prisma.invitation.findUnique({
      where: { id: invitationId },
      include: { from: true },
    });
    if (!invitation || invitation.proposalId !== proposalId) {
      throw new NotFoundException('Invitation not found for this proposal');
    }
    if (invitation.status !== InvitationStatus.pending) {
      throw new ConflictException('Inviter is no longer available');
    }
    // The budget was snapshotted at invite time; legacy rows without one
    // fall back to the scene's default tier.
    const feeMinor =
      invitation.budgetMinor > 0
        ? invitation.budgetMinor
        : await this.pricingService.resolveBudget(invitation.sceneTag);
    const split = await this.pricingService.splitFee(feeMinor);
    const order = await this.prisma.$transaction(async (tx) => {
      const post = await tx.post.create({
        data: {
          authorId: invitation.fromUserId,
          sceneTag: proposal.sceneTag,
          title: proposal.title,
          description: invitation.note,
          status: PostStatus.pendingPayment,
          origin: PostOrigin.direct,
          proposalId,
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
      // The host fills the plan card at selection (mirror of a sign-up's
      // plan card): the order is born with the plan confirmed, and the
      // inviter accepts it by paying.
      const planApproved = new Date();
      const created = await tx.order.create({
        data: {
          postId: post.id,
          payerId: invitation.fromUserId,
          earnerId: caller.id,
          status: OrderStatus.awaitingPayment,
          feeMinor: split.feeMinor,
          commissionMinor: split.commissionMinor,
          netMinor: split.netMinor,
          meetCode: generateMeetCode(),
          planPlace: plan.place,
          planAt: new Date(plan.scheduledAt),
          planDurationMinutes: plan.durationMinutes,
          planNote: plan.note,
          planProposedAt: planApproved,
          planConfirmedAt: planApproved,
        },
        include: { payer: true, earner: true, post: true },
      });
      // The locked plan card opens the conversation as its first message,
      // visible as soon as the payment unlocks the chat.
      await tx.message.create({
        data: {
          orderId: created.id,
          senderId: caller.id,
          kind: 'PLAN',
          text: JSON.stringify({
            place: plan.place,
            scheduledAt: plan.scheduledAt,
            durationMinutes: plan.durationMinutes,
            note: plan.note,
          }),
        },
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
      // Off the market while the payment is pending; paying moves it to
      // MATCHED, a cancelled order reopens it.
      await tx.proposal.update({
        where: { id: proposalId },
        data: { status: PostStatus.pendingPayment },
      });
      return created;
    });
    // The caller is the host (earner): the meet code stays hidden here.
    return toOrderDto(order, caller.id);
  }

  private async findProposalOrThrow(
    proposalId: string,
  ): Promise<ProposalWithHost> {
    const proposal = await this.prisma.proposal.findUnique({
      where: { id: proposalId },
      include: { host: true },
    });
    if (!proposal) {
      throw new NotFoundException('Proposal not found');
    }
    return proposal;
  }

  private async toProposalDto(
    proposal: ProposalWithHost,
    callerId: string,
  ): Promise<ProposalDto> {
    const [completed, inviteCount, mine] = await Promise.all([
      this.prisma.order.count({
        where: { earnerId: proposal.hostId, status: OrderStatus.completed },
      }),
      this.prisma.invitation.count({
        where: { proposalId: proposal.id, status: InvitationStatus.pending },
      }),
      this.prisma.invitation.findFirst({
        where: {
          proposalId: proposal.id,
          fromUserId: callerId,
          status: InvitationStatus.pending,
        },
        select: { id: true },
      }),
    ]);
    return {
      id: proposal.id,
      title: proposal.title,
      description: proposal.description,
      sceneTag: proposal.sceneTag,
      imageUrl: proposal.imageUrl,
      area: proposal.area,
      timeSlot: proposal.timeSlot,
      budgetMinor: proposal.budgetMinor,
      status: proposal.status,
      inviteCount,
      hasInvited: mine !== null,
      createdAt: proposal.createdAt,
      host: toPublicUser(proposal.host),
      hostCompletedActivities: completed,
    };
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
    invitation: InvitationWithFrom,
  ): InvitationDto {
    return {
      id: invitation.id,
      proposalId: invitation.proposalId,
      note: invitation.note,
      status: invitation.status,
      from: toPublicUser(invitation.from),
      createdAt: invitation.createdAt,
    };
  }
}
