import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Prisma, User } from '@prisma/client';
import {
  ApplicationStatus,
  LedgerAccount,
  LedgerEntryType,
  OrderStatus,
  PaymentStatus,
  PostStatus,
} from '../common/enums.js';
import {
  cancelWindowMs,
  forfeitAfterMs,
  payWindowMs,
  serviceRunMs,
} from '../common/settlement.util.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { PAYMENT_PROVIDER } from '../payments/payment.provider.js';
import type { PaymentProvider } from '../payments/payment.provider.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { assertVerified } from '../common/verification.util.js';
import { toMessageDto, toOrderDto } from './order.mapper.js';
import type { OrderDto, OrderWithParties } from './order.mapper.js';

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
    assertVerified(caller);
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
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.active, paidAt: new Date() },
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
    const updated = await this.prisma.order.update({
      where: { id: order.id },
      data: { startedAt: new Date() },
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

  /// Sends an order-scoped chat message (participants only).
  async sendMessage(caller: User, orderId: string, text: string) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    // The paywall: no contact channel of any kind before the fee is
    // escrowed (same rule as phone disclosure).
    if (order.status === OrderStatus.awaitingPayment) {
      throw new ConflictException('PAYMENT_REQUIRED');
    }
    // The conversation lives and dies with the activity: once the order
    // settles or cancels, the thread turns read-only (history stays
    // listable for both sides and for dispute reviews).
    if (
      order.status === OrderStatus.completed ||
      order.status === OrderStatus.cancelled ||
      order.status === OrderStatus.forfeited
    ) {
      throw new ConflictException('CHAT_CLOSED');
    }
    // Escrowed money IS the anti-bypass mechanism: once paid, both sides
    // chat freely while the activity is live.
    const message = await this.prisma.message.create({
      data: { orderId: order.id, senderId: caller.id, text },
    });
    return toMessageDto(message);
  }

  /// Lists messages oldest-first; pass afterId to fetch only newer ones
  /// (clients poll with the last seen id).
  async listMessages(caller: User, orderId: string, afterId?: string) {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
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
