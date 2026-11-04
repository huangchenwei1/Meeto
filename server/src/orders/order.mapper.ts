import type { Message, Order, Post, User } from '@prisma/client';
import { OrderStatus } from '../common/enums.js';
import { cancelWindowMs } from '../common/settlement.util.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';

export type OrderWithParties = Order & {
  payer: User;
  earner: User;
  post: Post;
};

export interface OrderDto {
  id: string;
  postId: string;
  payer: PublicUser;
  earner: PublicUser;
  status: string;
  feeMinor: number;
  commissionMinor: number;
  netMinor: number;
  /// Phones are disclosed to the participants once the fee is escrowed
  /// (ACTIVE and later), so the parties can coordinate directly.
  payerPhone: string;
  earnerPhone: string;
  /// Activity context so clients can present the order as a concrete plan
  /// (title · place · time) rather than a bare chat. Place and time are the
  /// EFFECTIVE values: set once the plan is confirmed, empty/zero/null
  /// before that (posts carry no structured time or place).
  postTitle: string;
  scheduledAt: Date | null;
  place: string;
  placeLat: number;
  placeLng: number;
  /// The host's proposed plan awaiting / after the poster's confirmation.
  /// Chat opens at payment and never re-locks while the order is active;
  /// the confirmed plan just becomes the effective place and time.
  planPlace: string;
  planLat: number;
  planLng: number;
  planAt: Date | null;
  planNote: string;
  planDurationMinutes: number;
  planProposedAt: Date | null;
  planConfirmedAt: Date | null;
  /// Proof-of-meeting code, disclosed ONLY to the payer (the viewer must
  /// be passed to the mapper): the host asks for it in person and submits
  /// it to start the service. Empty for everyone else.
  meetCode: string;
  /// Set when the host submitted the correct meet code: the service is
  /// running and auto-settles after its planned duration.
  startedAt: Date | null;
  /// Until when either side may still cancel with a full refund (payment
  /// time + the cancel window); null before payment or once started.
  cancellableUntil: Date | null;
  /// Set when the order closed (settled or forfeited).
  completedAt: Date | null;
  createdAt: Date;
}

const PHONE_DISCLOSED_STATUSES: ReadonlySet<string> = new Set([
  OrderStatus.active,
  OrderStatus.completed,
]);

export function toOrderDto(
  order: OrderWithParties,
  viewerId?: string,
): OrderDto {
  const disclosePhones = PHONE_DISCLOSED_STATUSES.has(order.status);
  const planConfirmed = order.planConfirmedAt !== null;
  const cancellable =
    order.status === OrderStatus.active &&
    order.startedAt === null &&
    order.paidAt !== null;
  return {
    id: order.id,
    postId: order.postId,
    payer: toPublicUser(order.payer),
    earner: toPublicUser(order.earner),
    status: order.status,
    feeMinor: order.feeMinor,
    commissionMinor: order.commissionMinor,
    netMinor: order.netMinor,
    payerPhone: disclosePhones ? order.payer.phone : '',
    earnerPhone: disclosePhones ? order.earner.phone : '',
    postTitle: order.post.title,
    scheduledAt: planConfirmed ? order.planAt : null,
    place: planConfirmed ? order.planPlace : '',
    placeLat: planConfirmed ? order.planLat : 0,
    placeLng: planConfirmed ? order.planLng : 0,
    planPlace: order.planPlace,
    planLat: order.planLat,
    planLng: order.planLng,
    planAt: order.planAt,
    planNote: order.planNote,
    planDurationMinutes: order.planDurationMinutes,
    planProposedAt: order.planProposedAt,
    planConfirmedAt: order.planConfirmedAt,
    meetCode: viewerId === order.payerId ? order.meetCode : '',
    startedAt: order.startedAt,
    cancellableUntil: cancellable
      ? new Date(order.paidAt!.getTime() + cancelWindowMs())
      : null,
    completedAt: order.completedAt,
    createdAt: order.createdAt,
  };
}

export interface MessageDto {
  id: string;
  orderId: string;
  senderId: string;
  /// TEXT for plain chat; PLAN for a plan card ([text] then carries the
  /// JSON snapshot {place, scheduledAt, note} frozen at send time).
  kind: string;
  text: string;
  createdAt: Date;
}

export function toMessageDto(message: Message): MessageDto {
  return {
    id: message.id,
    orderId: message.orderId,
    senderId: message.senderId,
    kind: message.kind,
    text: message.text,
    createdAt: message.createdAt,
  };
}
