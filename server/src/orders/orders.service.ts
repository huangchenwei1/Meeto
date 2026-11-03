import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import {
  ApplicationStatus,
  LedgerAccount,
  LedgerEntryType,
  NotificationType,
  OrderStatus,
  PaymentStatus,
  PostStatus,
} from '../common/enums.js';
import { autoSettleDelayMs } from '../common/settlement.util.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { PAYMENT_PROVIDER } from '../payments/payment.provider.js';
import type { PaymentProvider } from '../payments/payment.provider.js';
import { NotificationsService } from '../notifications/notifications.module.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { assertVerified } from '../common/verification.util.js';
import { toMessageDto, toOrderDto } from './order.mapper.js';
import type { OrderDto, OrderWithParties } from './order.mapper.js';

/// Server-authoritative order state machine.
///
///   AWAITING_PAYMENT --pay(escrow)--> ACTIVE (planning: no chat yet)
///   ACTIVE: the host proposes the plan (place + time); the plan card
///     opens the order chat; the poster confirms the plan.
///   ACTIVE --poster taps "completed"--> COMPLETED (escrow released to
///     the earner, commission booked)
///   ACTIVE --(confirmed planAt + AUTO_SETTLE_DELAY elapsed, lazy check
///     on reads)--> COMPLETED (fallback so the host always gets paid)
///   AWAITING_PAYMENT | ACTIVE --cancel--> CANCELLED
///           (full refund if escrowed; the post reopens)
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
    private readonly notifications: NotificationsService,
  ) {}

  async listMine(caller: User): Promise<OrderDto[]> {
    const orders = await this.prisma.order.findMany({
      where: { OR: [{ payerId: caller.id }, { earnerId: caller.id }] },
      include: { payer: true, earner: true, post: true },
      orderBy: { createdAt: 'desc' },
    });
    const settled = await Promise.all(
      orders.map((order) => this.maybeSettle(order)),
    );
    return settled.map(toOrderDto);
  }

  async getOne(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    return toOrderDto(await this.maybeSettle(order));
  }

  async listAll(status?: string): Promise<OrderDto[]> {
    const orders = await this.prisma.order.findMany({
      where: status ? { status } : undefined,
      include: { payer: true, earner: true, post: true },
      orderBy: { createdAt: 'desc' },
    });
    return orders.map(toOrderDto);
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
      await this.notifications.notify(tx, {
        userId: order.earnerId,
        type: NotificationType.orderPaid,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId: order.postId,
        orderId: order.id,
      });
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.active },
        include: { payer: true, earner: true, post: true },
      });
    });
    return toOrderDto(updated);
  }

  /// The poster single-sidedly marks the activity as done; the escrow
  /// settles immediately (ACTIVE orders only).
  async complete(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.payerId !== caller.id) {
      throw new ForbiddenException('Only the poster completes the activity');
    }
    if (order.status !== OrderStatus.active) {
      throw new ConflictException('Order is not active');
    }
    return toOrderDto(await this.settle(order));
  }

  /// The host proposes (or re-proposes) the concrete plan: place + time.
  /// Allowed while the order is ACTIVE (paid). Re-proposing clears a
  /// previous confirmation. Mainly the invitation path: selection orders
  /// already carry the sign-up plan card, approved at selection.
  async proposePlan(
    caller: User,
    orderId: string,
    input: {
      place: string;
      placeLat?: number;
      placeLng?: number;
      scheduledAt: string;
      note: string;
    },
  ): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.earnerId !== caller.id) {
      throw new ForbiddenException('Only the host proposes the plan');
    }
    if (order.status !== OrderStatus.active) {
      throw new ConflictException('Plan can be proposed while the order is active');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      await this.notifications.notify(tx, {
        userId: order.payerId,
        type: NotificationType.planProposed,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId: order.postId,
        orderId: order.id,
      });
      // The plan card lands in the conversation as a message, frozen as a
      // snapshot: a later re-proposal adds a new card instead of rewriting
      // this one.
      await tx.message.create({
        data: {
          orderId: order.id,
          senderId: caller.id,
          kind: 'PLAN',
          text: JSON.stringify({
            place: input.place,
            scheduledAt: input.scheduledAt,
            note: input.note,
          }),
        },
      });
      return tx.order.update({
        where: { id: order.id },
        data: {
          planPlace: input.place,
          planLat: input.placeLat ?? 0,
          planLng: input.placeLng ?? 0,
          planAt: new Date(input.scheduledAt),
          planNote: input.note,
          planProposedAt: new Date(),
          planConfirmedAt: null,
        },
        include: { payer: true, earner: true, post: true },
      });
    });
    return toOrderDto(updated);
  }

  /// The poster locks in the host's proposed plan.
  async confirmPlan(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (order.payerId !== caller.id) {
      throw new ForbiddenException('Only the poster confirms the plan');
    }
    if (order.status !== OrderStatus.active) {
      throw new ConflictException('Plan can be confirmed while the order is active');
    }
    if (order.planProposedAt === null) {
      throw new ConflictException('No plan has been proposed yet');
    }
    if (order.planConfirmedAt !== null) {
      throw new ConflictException('Plan is already confirmed');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      await this.notifications.notify(tx, {
        userId: order.earnerId,
        type: NotificationType.planConfirmed,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId: order.postId,
        orderId: order.id,
      });
      return tx.order.update({
        where: { id: order.id },
        data: { planConfirmedAt: new Date() },
        include: { payer: true, earner: true, post: true },
      });
    });
    return toOrderDto(updated);
  }

  /// Lazy fallback settlement: an ACTIVE order whose confirmed plan time
  /// plus the grace delay has passed settles on the next read (clients
  /// poll orders constantly, so this needs no scheduler). Protects the
  /// host when the poster never taps "completed".
  private async maybeSettle(
    order: OrderWithParties,
  ): Promise<OrderWithParties> {
    if (
      order.status !== OrderStatus.active ||
      order.planConfirmedAt === null ||
      order.planAt === null ||
      order.planAt.getTime() + autoSettleDelayMs() > Date.now()
    ) {
      return order;
    }
    return this.settle(order);
  }

  /// Releases the escrow to the earner and books the commission. Shared by
  /// the poster's explicit completion and the lazy auto-settle fallback.
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
      await this.notifications.notify(tx, {
        userId: order.earnerId,
        type: NotificationType.orderSettled,
        postId: order.postId,
        orderId: order.id,
      });
      return tx.order.update({
        where: { id: order.id },
        data: { status: OrderStatus.completed, completedAt: new Date() },
        include: { payer: true, earner: true, post: true },
      });
    });
  }

  /// Either participant cancels before completion. Escrowed money is
  /// refunded in full; the post reopens for a new selection.
  async cancel(caller: User, orderId: string): Promise<OrderDto> {
    const order = await this.findParticipantOrderOrThrow(caller, orderId);
    if (
      order.status !== OrderStatus.awaitingPayment &&
      order.status !== OrderStatus.active
    ) {
      throw new ConflictException('Order can no longer be cancelled');
    }
    const wasEscrowed = order.status === OrderStatus.active;

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
      await this.notifications.notify(tx, {
        userId: order.payerId === caller.id ? order.earnerId : order.payerId,
        type: NotificationType.orderCancelled,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId: order.postId,
        orderId: order.id,
      });
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
    return toOrderDto(updated);
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
      order.status === OrderStatus.cancelled
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
