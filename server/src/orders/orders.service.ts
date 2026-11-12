import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Message, Prisma, User } from '@prisma/client';
import {
  ApplicationStatus,
  LedgerAccount,
  LedgerEntryType,
  OrderStatus,
  PaymentStatus,
  PostOrigin,
  PostStatus,
  ReportStatus,
} from '../common/enums.js';
import { generateMeetCode } from '../common/meet-code.util.js';
import {
  cancelWindowMs,
  forfeitAfterMs,
  payWindowMs,
  serviceRunMs,
} from '../common/settlement.util.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { PAYMENT_PROVIDER } from '../payments/payment.provider.js';
import type { PaymentProvider } from '../payments/payment.provider.js';
import {
  ACTIVITY_DURATION_MINUTES,
  findTemplate,
  isWithinMeetingHours,
} from '../posts/activity-templates.js';
import { PricingService } from '../pricing/pricing.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { toMessageDto, toOrderDto } from './order.mapper.js';
import type { OrderDto, OrderWithParties } from './order.mapper.js';

/// One row of the contact-style conversation list: the partner, the room
/// to open, and a preview of the latest message across ALL shared deals.
export interface ConversationDto {
  peer: PublicUser;
  /// The order whose room this conversation opens into: the live deal
  /// when one exists, otherwise the latest settled one.
  roomOrderId: string;
  /// True when a deal with this partner is currently running.
  hasLiveOrder: boolean;
  /// Preview of the newest message across the shared orders; kind lets
  /// clients label card messages instead of dumping their JSON.
  lastMessageKind: string;
  lastMessageText: string;
  lastMessageAt: Date | null;
  /// Messages from the partner past the caller's read cursor, summed
  /// across all shared orders. Badges the row and the Messages tab.
  unreadCount: number;
  /// Sort anchor: last message time, or the room's creation time.
  sortedAt: Date;
}

/// The JSON payload carried in a REQUEST message's [text]: a rebooking
/// card the payer sends to the host inside an existing conversation.
/// Snapshotted at send time; responding mutates only [status]/[orderId].
interface ActivityRequestPayload {
  templateId: string;
  title: string;
  meetingPoint: string;
  scheduledAt: string;
  budgetMinor: number;
  note: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED';
  /// The order created from this request, set on acceptance.
  orderId: string;
}

/// Server-authoritative order state machine.
///
///   AWAITING_PAYMENT --pay(escrow)--> ACTIVE (chat opens). Unpaid past
///     the pay window --> CANCELLED (lazy, on reads); the post/proposal
///     goes back on the market.
///   ACTIVE: the plan was locked at the deal moment (sign-up plan card /
///     host's selection plan card), so chat carries no plan negotiation.
///     At the meeting the host asks the payer for the 4-digit meet code
///     and submits it --> the service starts (startedAt).
///   started + planned duration elapsed (lazy check on reads) -->
///     COMPLETED (escrow released to the earner, commission booked).
///   AWAITING_PAYMENT --cancel--> CANCELLED (nothing escrowed yet).
///   ACTIVE --cancel within the 30-minute window after payment, not yet
///     started--> CANCELLED (full refund; the post reopens).
///   ACTIVE, never started, planned time + forfeit delay passed -->
///     FORFEITED: the escrow goes to NEITHER side (platform keeps it;
///     extreme cases are handled manually). Nobody showed, nobody cared.
///
/// Settlement invariant: fee = commission + net; every settlement posts a
/// balanced ledger batch (sum of entries = 0).
@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledgerService: LedgerService,
    private readonly pricingService: PricingService,
    @Inject(PAYMENT_PROVIDER)
    private readonly paymentProvider: PaymentProvider,
  ) {}

  /// How long a settled/cancelled conversation stays in the list before
  /// it disappears for the participants. The records themselves are kept
  /// (read-only) for dispute reviews.
  private static readonly CLOSED_ORDER_GRACE_MS = 7 * 24 * 3600 * 1000;

  /// Two views over the caller's orders:
  /// - default (the Messages tab): conversations only — money already in
  ///   escrow. Unpaid orders never show (no chat before escrow), and
  ///   closed ones linger for a grace week, then leave.
  /// - view=all (the My Orders page): every order in every status, the
  ///   full history.
  async listMine(caller: User, view?: string): Promise<OrderDto[]> {
    const orders = await this.prisma.order.findMany({
      where: { OR: [{ payerId: caller.id }, { earnerId: caller.id }] },
      include: { payer: true, earner: true, post: true },
      orderBy: { createdAt: 'desc' },
    });
    const settled = await Promise.all(
      orders.map((order) => this.maybeSettle(order)),
    );
    const all = view === 'all';
    const cutoff = Date.now() - OrdersService.CLOSED_ORDER_GRACE_MS;
    const visible = settled.filter((order) => {
      if (all) {
        return true;
      }
      if (order.status === OrderStatus.awaitingPayment) {
        return false;
      }
      if (order.status === OrderStatus.active) {
        return true;
      }
      // Dead deals carry no conversation worth revisiting: cancelled and
      // forfeited orders live only on the My Orders page. Completed ones
      // linger for the grace window so the recap stays reachable.
      if (order.status !== OrderStatus.completed) {
        return false;
      }
      const closedAt = order.completedAt ?? order.createdAt;
      return closedAt.getTime() >= cutoff;
    });
    return visible.map((order) => toOrderDto(order, caller.id));
  }

  async getOne(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    return toOrderDto(await this.maybeSettle(order), caller.id);
  }

  /// The contact-style conversation list: the caller's deals grouped by
  /// the OTHER person, newest activity first. One row per partner — the
  /// relationship, not the order, is the unit — because settled chats
  /// stay open and rebooking happens inside them. Dead deals (cancelled /
  /// forfeited) carry no conversation and are excluded; unlike the order
  /// board there is no expiry: partners do not time out.
  async listConversations(caller: User): Promise<ConversationDto[]> {
    const orders = await this.prisma.order.findMany({
      where: {
        OR: [{ payerId: caller.id }, { earnerId: caller.id }],
        status: { in: [OrderStatus.active, OrderStatus.completed] },
      },
      include: { payer: true, earner: true, post: true },
      orderBy: { createdAt: 'desc' },
    });
    // Run the lazy money clock, then regroup on fresh statuses.
    const settled = await Promise.all(
      orders.map((order) => this.maybeSettle(order)),
    );
    const byPeer = new Map<string, OrderWithParties[]>();
    for (const order of settled) {
      if (
        order.status !== OrderStatus.active &&
        order.status !== OrderStatus.completed
      ) {
        continue;
      }
      const peerId =
        order.payerId === caller.id ? order.earnerId : order.payerId;
      const group = byPeer.get(peerId);
      if (group) {
        group.push(order);
      } else {
        byPeer.set(peerId, [order]);
      }
    }
    const conversations = await Promise.all(
      [...byPeer.values()].map(async (group) => {
        // The row opens into the live deal's room when one exists,
        // otherwise the latest settled one (groups keep newest-first).
        const room =
          group.find((o) => o.status === OrderStatus.active) ?? group[0];
        const peer = room.payerId === caller.id ? room.earner : room.payer;
        const lastMessage = await this.prisma.message.findFirst({
          where: { orderId: { in: group.map((o) => o.id) } },
          orderBy: { createdAt: 'desc' },
        });
        // Unread = the partner's messages past my per-order read cursor,
        // summed across every order we share.
        const unreadCounts = await Promise.all(
          group.map((order) => {
            const lastReadAt =
              order.payerId === caller.id
                ? order.payerLastReadAt
                : order.earnerLastReadAt;
            return this.prisma.message.count({
              where: {
                orderId: order.id,
                senderId: { not: caller.id },
                ...(lastReadAt ? { createdAt: { gt: lastReadAt } } : {}),
              },
            });
          }),
        );
        return {
          peer: toPublicUser(peer),
          roomOrderId: room.id,
          hasLiveOrder: room.status === OrderStatus.active,
          lastMessageKind: lastMessage?.kind ?? '',
          lastMessageText: lastMessage?.text ?? '',
          lastMessageAt: lastMessage?.createdAt ?? null,
          unreadCount: unreadCounts.reduce((sum, n) => sum + n, 0),
          sortedAt: lastMessage?.createdAt ?? room.createdAt,
        };
      }),
    );
    conversations.sort(
      (a, b) => b.sortedAt.getTime() - a.sortedAt.getTime(),
    );
    return conversations;
  }

  async listAll(status?: string): Promise<OrderDto[]> {
    const orders = await this.prisma.order.findMany({
      where: status ? { status } : undefined,
      include: { payer: true, earner: true, post: true },
      orderBy: { createdAt: 'desc' },
    });
    return orders.map((order) => toOrderDto(order));
  }

  /// Payer escrows the match fee through the payment channel.
  async pay(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.payerId !== caller.id) {
      throw new ForbiddenException('Only the payer can pay this order');
    }
    if (order.status !== OrderStatus.awaitingPayment) {
      throw new ConflictException('Order is not awaiting payment');
    }

    // Charge first (idempotency / webhooks are the production concern of the
    // real channel adapter), then record everything atomically.
    await this.paymentProvider.charge({
      orderId: order.id,
      payerId: caller.id,
      amountMinor: order.feeMinor,
    });

    const updated = await this.prisma.$transaction(async (tx) => {
      // Atomic claim: AWAITING_PAYMENT -> ACTIVE is the mutex. A racing
      // double submission loses here, the transaction rolls back, and
      // the escrow is never double-booked.
      const claimed = await tx.order.updateMany({
        where: { id: order.id, status: OrderStatus.awaitingPayment },
        data: { status: OrderStatus.active, paidAt: new Date() },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Order is not awaiting payment');
      }
      await tx.payment.create({
        data: {
          orderId: order.id,
          amountMinor: order.feeMinor,
          status: PaymentStatus.succeeded,
        },
      });
      await this.ledgerService.postEntries(tx, [
        {
          account: LedgerAccount.platformEscrow,
          entryType: LedgerEntryType.escrowIn,
          amountMinor: order.feeMinor,
          orderId: order.id,
        },
      ]);
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.matched },
      });
      await OrdersService.syncProposal(tx, order, PostStatus.matched);
      return tx.order.findUniqueOrThrow({
        where: { id: order.id },
        include: { payer: true, earner: true, post: true },
      });
    });
    return toOrderDto(updated, caller.id);
  }

  /// The host submits the payer's 4-digit meet code at the meeting: the
  /// only proof of meeting the platform accepts. A correct code starts
  /// the service clock; the escrow settles automatically once the planned
  /// duration runs out — no further taps from anyone.
  async start(caller: User, orderId: string, code: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.earnerId !== caller.id) {
      throw new ForbiddenException('Only the host submits the meet code');
    }
    if (order.status !== OrderStatus.active) {
      throw new ConflictException('Order is not active');
    }
    if (order.startedAt !== null) {
      throw new ConflictException('ALREADY_STARTED');
    }
    if (code !== order.meetCode) {
      throw new ConflictException('WRONG_MEET_CODE');
    }
    // Conditional write: only the first correct submission may set the
    // clock, so a racing double tap cannot restart it.
    const claimed = await this.prisma.order.updateMany({
      where: { id: order.id, status: OrderStatus.active, startedAt: null },
      data: { startedAt: new Date() },
    });
    if (claimed.count === 0) {
      throw new ConflictException('ALREADY_STARTED');
    }
    const updated = await this.prisma.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { payer: true, earner: true, post: true },
    });
    return toOrderDto(updated, caller.id);
  }

  /// Lazy money clock, run on every read (clients poll orders constantly,
  /// so this needs no scheduler):
  /// - an unpaid order auto-cancels once the pay window runs out and the
  ///   post/proposal goes back on the market;
  /// - a started service settles once its planned duration has run out;
  /// - a never-started order forfeits once the planned time (or payment,
  ///   when no plan was ever set) is a forfeit-delay in the past.
  private async maybeSettle(
    order: OrderWithParties,
  ): Promise<OrderWithParties> {
    if (order.status === OrderStatus.awaitingPayment) {
      return order.createdAt.getTime() + payWindowMs() <= Date.now()
        ? this.expireUnpaid(order)
        : order;
    }
    if (order.status !== OrderStatus.active) {
      return order;
    }
    // An OPEN safety report freezes the money clock both ways (settle
    // and forfeit) — the community guidelines promise settlement holds
    // during review. Ops resolves the report; the next read settles.
    const heldByReport = await this.prisma.report.count({
      where: { orderId: order.id, status: ReportStatus.open },
    });
    if (heldByReport > 0) {
      return order;
    }
    if (order.startedAt !== null) {
      const endsAt =
        order.startedAt.getTime() + serviceRunMs(order.planDurationMinutes);
      return endsAt <= Date.now() ? this.settle(order) : order;
    }
    const anchor = order.planAt ?? order.paidAt;
    if (anchor !== null && anchor.getTime() + forfeitAfterMs() <= Date.now()) {
      return this.forfeit(order);
    }
    return order;
  }

  /// Releases the escrow to the earner and books the commission once the
  /// started service has run its planned duration.
  private async settle(order: OrderWithParties): Promise<OrderWithParties> {
    return this.prisma.$transaction(async (tx) => {
      // Re-check inside the transaction: a concurrent read may have
      // settled (or a cancel may have landed) between the check and now.
      const current = await tx.order.findUnique({
        where: { id: order.id },
      });
      if (!current || current.status !== OrderStatus.active) {
        return (await tx.order.findUnique({
          where: { id: order.id },
          include: { payer: true, earner: true, post: true },
        }))!;
      }
      // Release escrow, pay the earner, book commission.
      await this.ledgerService.postEntries(tx, [
        {
          account: LedgerAccount.platformEscrow,
          entryType: LedgerEntryType.escrowRelease,
          amountMinor: -order.feeMinor,
          orderId: order.id,
        },
        {
          account: LedgerAccount.userWallet,
          entryType: LedgerEntryType.settleNet,
          amountMinor: order.netMinor,
          userId: order.earnerId,
          orderId: order.id,
        },
        {
          account: LedgerAccount.platformRevenue,
          entryType: LedgerEntryType.settleCommission,
          amountMinor: order.commissionMinor,
          orderId: order.id,
        },
      ]);
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.completed },
      });
      await OrdersService.syncProposal(tx, order, PostStatus.completed);
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.completed, completedAt: new Date() },
        include: { payer: true, earner: true, post: true },
      });
    });
  }

  /// Nobody submitted the meet code in time: the escrow goes to NEITHER
  /// side. The payment stays booked as platform revenue (extreme cases
  /// get a manual refund through support); the post closes for good.
  private async forfeit(order: OrderWithParties): Promise<OrderWithParties> {
    return this.prisma.$transaction(async (tx) => {
      // Re-check inside the transaction: a concurrent start/cancel may
      // have landed between the check and now.
      const current = await tx.order.findUnique({ where: { id: order.id } });
      if (
        !current ||
        current.status !== OrderStatus.active ||
        current.startedAt !== null
      ) {
        return (await tx.order.findUnique({
          where: { id: order.id },
          include: { payer: true, earner: true, post: true },
        }))!;
      }
      await this.ledgerService.postEntries(tx, [
        {
          account: LedgerAccount.platformEscrow,
          entryType: LedgerEntryType.escrowForfeit,
          amountMinor: -order.feeMinor,
          orderId: order.id,
        },
        {
          account: LedgerAccount.platformRevenue,
          entryType: LedgerEntryType.escrowForfeit,
          amountMinor: order.feeMinor,
          orderId: order.id,
        },
      ]);
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.cancelled },
      });
      await OrdersService.syncProposal(tx, order, PostStatus.cancelled);
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.forfeited, completedAt: new Date() },
        include: { payer: true, earner: true, post: true },
      });
    });
  }

  /// Either participant backs out with a full refund — but only within
  /// the cancel window after payment (enough time to talk it over), and
  /// never once the service started. Unpaid orders cancel freely.
  async cancel(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (
      order.status !== OrderStatus.awaitingPayment &&
      order.status !== OrderStatus.active
    ) {
      throw new ConflictException('Order can no longer be cancelled');
    }
    const wasEscrowed = order.status === OrderStatus.active;
    if (wasEscrowed) {
      if (order.startedAt !== null) {
        throw new ConflictException('ALREADY_STARTED');
      }
      const paidAt = order.paidAt ?? order.createdAt;
      if (paidAt.getTime() + cancelWindowMs() <= Date.now()) {
        throw new ConflictException('CANCEL_WINDOW_CLOSED');
      }
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      if (wasEscrowed) {
        await tx.payment.updateMany({
          where: { orderId: order.id, status: PaymentStatus.succeeded },
          data: { status: PaymentStatus.refunded },
        });
        await this.ledgerService.postEntries(tx, [
          {
            account: LedgerAccount.platformEscrow,
            entryType: LedgerEntryType.escrowRefund,
            amountMinor: -order.feeMinor,
            orderId: order.id,
          },
        ]);
      }
      // Release the selected candidate and reopen the post.
      await tx.application.updateMany({
        where: { postId: order.postId, status: ApplicationStatus.selected },
        data: { status: ApplicationStatus.released },
      });
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.open },
      });
      // A proposal-born deal that falls through puts the pitch back on
      // the market, exactly like a reopened demand post.
      await OrdersService.syncProposal(tx, order, PostStatus.open);
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.cancelled },
        include: { payer: true, earner: true, post: true },
      });
    });

    if (wasEscrowed) {
      // Outside the DB transaction: instruct the channel to refund. A real
      // adapter would do this via an async job with retries.
      await this.paymentProvider.refund(order.id, order.feeMinor);
    }
    return toOrderDto(updated, caller.id);
  }

  /// A participant files an in-room safety report. While it stays OPEN
  /// the order's automatic settlement is frozen (see maybeSettle), so
  /// ops can still refund a disputed deal.
  async report(
    caller: User,
    orderId: string,
    reason: string,
  ): Promise<{ id: string }> {
    const trimmed = reason.trim();
    if (trimmed.length === 0) {
      throw new BadRequestException('A report needs a reason');
    }
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    const report = await this.prisma.report.create({
      data: { orderId: order.id, reporterId: caller.id, reason: trimmed },
    });
    return { id: report.id };
  }

  /// Ops-only dispute resolution: force-refund an ACTIVE order in full,
  /// ignoring the cancel window and the started flag. The post does NOT
  /// reopen (a disputed deal should not quietly go back on the market);
  /// pending candidates are released so nobody stays stuck "selected".
  async adminRefund(orderId: string): Promise<OrderDto> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { payer: true, earner: true, post: true },
    });
    if (!order) {
      throw new NotFoundException('Order not found');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      // Atomic claim, same pattern as cancel/pay: only one resolution
      // can land on an active order.
      const claimed = await tx.order.updateMany({
        where: { id: orderId, status: OrderStatus.active },
        data: { status: OrderStatus.cancelled },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Only active orders can be refunded');
      }
      await tx.payment.updateMany({
        where: { orderId, status: PaymentStatus.succeeded },
        data: { status: PaymentStatus.refunded },
      });
      await this.ledgerService.postEntries(tx, [
        {
          account: LedgerAccount.platformEscrow,
          entryType: LedgerEntryType.escrowRefund,
          amountMinor: -order.feeMinor,
          orderId: order.id,
        },
      ]);
      await tx.application.updateMany({
        where: { postId: order.postId, status: ApplicationStatus.selected },
        data: { status: ApplicationStatus.released },
      });
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.cancelled },
      });
      await OrdersService.syncProposal(tx, order, PostStatus.cancelled);
      return tx.order.findUniqueOrThrow({
        where: { id: orderId },
        include: { payer: true, earner: true, post: true },
      });
    });
    await this.paymentProvider.refund(order.id, order.feeMinor);
    // No caller perspective: the admin view never exposes the meet code.
    return toOrderDto(updated, '');
  }

  /// Sends an order-scoped chat message (participants only).
  async sendMessage(caller: User, orderId: string, text: string) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    this.assertChatWritable(order);
    // Escrowed money IS the anti-bypass mechanism: once paid, both sides
    // chat freely while the activity is live.
    const message = await this.prisma.message.create({
      data: { orderId: order.id, senderId: caller.id, text },
    });
    return toMessageDto(message);
  }

  /// Chat write-gate. The paywall: no contact channel of any kind before
  /// the fee is escrowed (same rule as phone disclosure). A COMPLETED
  /// conversation stays open — the relationship outlives the activity, and
  /// rebooking a known host happens right here. Only dead deals
  /// (cancelled / forfeited) turn read-only.
  private assertChatWritable(order: OrderWithParties): void {
    if (order.status === OrderStatus.awaitingPayment) {
      throw new ConflictException('PAYMENT_REQUIRED');
    }
    if (
      order.status === OrderStatus.cancelled ||
      order.status === OrderStatus.forfeited
    ) {
      throw new ConflictException('CHAT_CLOSED');
    }
  }

  /// The payer sends an activity-request card into an existing (live or
  /// settled) conversation: the rebooking path for people who already met.
  /// Template-only like every activity; the payer brings the concrete time
  /// and the price tier, exactly as on a proposal invitation. One pending
  /// card per conversation.
  async sendActivityRequest(
    caller: User,
    orderId: string,
    templateId: string,
    scheduledAt: string,
    budgetMinor: number | undefined,
    note: string,
  ) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    this.assertChatWritable(order);
    if (order.payerId !== caller.id) {
      throw new ForbiddenException('Only the payer sends activity requests');
    }
    const template = findTemplate(templateId);
    if (!template) {
      throw new NotFoundException('TEMPLATE_NOT_FOUND');
    }
    const meetAt = new Date(scheduledAt);
    if (!isWithinMeetingHours(meetAt)) {
      throw new BadRequestException('MEET_TIME_OUT_OF_HOURS');
    }
    if ((await this.findPendingRequest(order.id)) !== null) {
      throw new ConflictException('REQUEST_ALREADY_PENDING');
    }
    const budget = await this.pricingService.resolveBudget(
      template.sceneTag,
      budgetMinor,
    );
    const payload: ActivityRequestPayload = {
      templateId: template.id,
      title: template.title,
      meetingPoint: template.meetingPoint,
      scheduledAt: meetAt.toISOString(),
      budgetMinor: budget,
      note,
      status: 'PENDING',
      orderId: '',
    };
    const message = await this.prisma.message.create({
      data: {
        orderId: order.id,
        senderId: caller.id,
        kind: 'REQUEST',
        text: JSON.stringify(payload),
      },
    });
    return toMessageDto(message);
  }

  /// The host answers an activity-request card. Declining just marks the
  /// card; accepting creates the whole new deal in one transaction — a
  /// direct post, a selected application and an order awaiting the
  /// requester's payment — mirroring proposal selection, with the plan
  /// locked to the card's terms.
  async respondActivityRequest(
    caller: User,
    orderId: string,
    messageId: string,
    accept: boolean,
  ) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.earnerId !== caller.id) {
      throw new ForbiddenException('Only the host answers activity requests');
    }
    const message = await this.prisma.message.findUnique({
      where: { id: messageId },
    });
    if (
      !message ||
      message.orderId !== order.id ||
      message.kind !== 'REQUEST'
    ) {
      throw new NotFoundException('Request not found in this conversation');
    }
    const payload = JSON.parse(message.text) as ActivityRequestPayload;
    if (payload.status !== 'PENDING') {
      throw new ConflictException('REQUEST_NOT_PENDING');
    }

    if (!accept) {
      const updated = await this.prisma.message.update({
        where: { id: message.id },
        data: {
          text: JSON.stringify({ ...payload, status: 'DECLINED' }),
        },
      });
      return toMessageDto(updated);
    }

    const planAt = new Date(payload.scheduledAt);
    // A card whose meeting time already passed cannot form a deal.
    if (planAt.getTime() <= Date.now()) {
      throw new ConflictException('REQUEST_EXPIRED');
    }
    const template = findTemplate(payload.templateId);
    const split = await this.pricingService.splitFee(payload.budgetMinor);
    const updated = await this.prisma.$transaction(async (tx) => {
      const post = await tx.post.create({
        data: {
          authorId: order.payerId,
          sceneTag: template?.sceneTag ?? order.post.sceneTag,
          title: payload.title,
          description: payload.note,
          templateId: payload.templateId,
          scheduledAt: planAt,
          area: template?.area ?? '',
          imageUrl: template?.imageUrl ?? '',
          status: PostStatus.pendingPayment,
          origin: PostOrigin.direct,
          feeMinor: split.feeMinor,
        },
      });
      await tx.application.create({
        data: {
          postId: post.id,
          applicantId: caller.id,
          status: ApplicationStatus.selected,
        },
      });
      const planApproved = new Date();
      const created = await tx.order.create({
        data: {
          postId: post.id,
          payerId: order.payerId,
          earnerId: caller.id,
          status: OrderStatus.awaitingPayment,
          feeMinor: split.feeMinor,
          commissionMinor: split.commissionMinor,
          netMinor: split.netMinor,
          meetCode: generateMeetCode(),
          planPlace: payload.meetingPoint,
          planAt,
          planDurationMinutes: ACTIVITY_DURATION_MINUTES,
          planProposedAt: planApproved,
          planConfirmedAt: planApproved,
        },
      });
      // The locked plan card opens the new conversation as its first
      // message, visible as soon as the payment unlocks the chat.
      await tx.message.create({
        data: {
          orderId: created.id,
          senderId: caller.id,
          kind: 'PLAN',
          text: JSON.stringify({
            place: payload.meetingPoint,
            scheduledAt: planAt.toISOString(),
            durationMinutes: ACTIVITY_DURATION_MINUTES,
            note: '',
          }),
        },
      });
      return tx.message.update({
        where: { id: message.id },
        data: {
          text: JSON.stringify({
            ...payload,
            status: 'ACCEPTED',
            orderId: created.id,
          }),
        },
      });
    });
    return toMessageDto(updated);
  }

  /// The conversation's open activity-request card, if any.
  private async findPendingRequest(orderId: string): Promise<Message | null> {
    const requests = await this.prisma.message.findMany({
      where: { orderId, kind: 'REQUEST' },
    });
    return (
      requests.find((m) => {
        const payload = JSON.parse(m.text) as ActivityRequestPayload;
        return payload.status === 'PENDING';
      }) ?? null
    );
  }

  /// Lists messages oldest-first; pass afterId to fetch only newer ones
  /// (clients poll with the last seen id).
  async listMessages(caller: User, orderId: string, afterId?: string) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    // Reading the room advances the caller's read cursor: everything the
    // other side sent up to now stops counting as unread. Polling clients
    // keep the cursor fresh for free.
    await this.prisma.order.update({
      where: { id: order.id },
      data:
        order.payerId === caller.id
          ? { payerLastReadAt: new Date() }
          : { earnerLastReadAt: new Date() },
    });
    let afterCreatedAt: Date | undefined;
    if (afterId) {
      const anchor = await this.prisma.message.findUnique({
        where: { id: afterId },
      });
      if (anchor && anchor.orderId === order.id) {
        afterCreatedAt = anchor.createdAt;
      }
    }
    const messages = await this.prisma.message.findMany({
      where: {
        orderId: order.id,
        ...(afterCreatedAt ? { createdAt: { gt: afterCreatedAt } } : {}),
      },
      orderBy: { createdAt: 'asc' },
    });
    return messages.map(toMessageDto);
  }

  /// An unpaid order ran out its pay window: cancel it and put the post
  /// (and its proposal, for invitation deals) back on the market. No
  /// money ever moved, so there is nothing to refund.
  private async expireUnpaid(
    order: OrderWithParties,
  ): Promise<OrderWithParties> {
    return this.prisma.$transaction(async (tx) => {
      // Re-check inside the transaction: a concurrent payment or cancel
      // may have landed between the check and now.
      const current = await tx.order.findUnique({ where: { id: order.id } });
      if (!current || current.status !== OrderStatus.awaitingPayment) {
        return (await tx.order.findUnique({
          where: { id: order.id },
          include: { payer: true, earner: true, post: true },
        }))!;
      }
      await tx.application.updateMany({
        where: { postId: order.postId, status: ApplicationStatus.selected },
        data: { status: ApplicationStatus.released },
      });
      await tx.post.update({
        where: { id: order.postId },
        data: { status: PostStatus.open },
      });
      await OrdersService.syncProposal(tx, order, PostStatus.open);
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.cancelled, completedAt: new Date() },
        include: { payer: true, earner: true, post: true },
      });
    });
  }

  /// DIRECT posts born from selecting an invitation on a proposal carry
  /// the proposal link: the order lifecycle mirrors its status back onto
  /// that proposal so the pitch leaves or re-enters the hall correctly.
  private static async syncProposal(
    tx: Prisma.TransactionClient,
    order: OrderWithParties,
    status: string,
  ): Promise<void> {
    if (order.post.proposalId !== '') {
      await tx.proposal.update({
        where: { id: order.post.proposalId },
        data: { status },
      });
    }
  }

  private async findParticipantOrderOrThrow(
    caller: User,
    orderId: string,
  ): Promise<OrderWithParties> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: { payer: true, earner: true, post: true },
    });
    if (!order) {
      throw new NotFoundException('Order not found');
    }
    if (order.payerId !== caller.id && order.earnerId !== caller.id) {
      throw new ForbiddenException('Not a participant of this order');
    }
    return order;
  }
}
