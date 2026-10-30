import type { Message, Order, Post, User } from '@prisma/client';
import { distanceKm, meetSettleDelayMs } from '../common/geo.util.js';
import { OrderStatus } from '../common/enums.js';
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
  /// Distance between the latest location snapshots; null until both sides
  /// have reported a location.
  distanceKm: number | null;
  /// Latest location snapshots, shared with both participants while the
  /// date is being coordinated (map display); null until reported.
  payerLat: number | null;
  payerLng: number | null;
  earnerLat: number | null;
  earnerLng: number | null;
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
  planPlace: string;
  planLat: number;
  planLng: number;
  planAt: Date | null;
  planProposedAt: Date | null;
  planConfirmedAt: Date | null;
  payerMetAt: Date | null;
  earnerMetAt: Date | null;
  metAt: Date | null;
  /// When the escrow auto-settles (metAt + delay); null before MET.
  settleAt: Date | null;
  disputed: boolean;
  createdAt: Date;
}

const PHONE_DISCLOSED_STATUSES: ReadonlySet<string> = new Set([
  OrderStatus.active,
  OrderStatus.met,
  OrderStatus.completed,
  OrderStatus.disputed,
]);

export function toOrderDto(order: OrderWithParties): OrderDto {
  const disclosePhones = PHONE_DISCLOSED_STATUSES.has(order.status);
  const planConfirmed = order.planConfirmedAt !== null;
  const hasBothLocations =
    order.payerLat !== null &&
    order.payerLng !== null &&
    order.earnerLat !== null &&
    order.earnerLng !== null;
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
    distanceKm: hasBothLocations
      ? distanceKm(
          order.payerLat!,
          order.payerLng!,
          order.earnerLat!,
          order.earnerLng!,
        )
      : null,
    payerLat: order.payerLat,
    payerLng: order.payerLng,
    earnerLat: order.earnerLat,
    earnerLng: order.earnerLng,
    postTitle: order.post.title,
    scheduledAt: planConfirmed ? order.planAt : null,
    place: planConfirmed ? order.planPlace : '',
    placeLat: planConfirmed ? order.planLat : 0,
    placeLng: planConfirmed ? order.planLng : 0,
    planPlace: order.planPlace,
    planLat: order.planLat,
    planLng: order.planLng,
    planAt: order.planAt,
    planProposedAt: order.planProposedAt,
    planConfirmedAt: order.planConfirmedAt,
    payerMetAt: order.payerMetAt,
    earnerMetAt: order.earnerMetAt,
    metAt: order.metAt,
    settleAt: order.metAt
      ? new Date(order.metAt.getTime() + meetSettleDelayMs())
      : null,
    disputed: order.disputedAt !== null,
    createdAt: order.createdAt,
  };
}

export interface MessageDto {
  id: string;
  orderId: string;
  senderId: string;
  text: string;
  createdAt: Date;
}

export function toMessageDto(message: Message): MessageDto {
  return {
    id: message.id,
    orderId: message.orderId,
    senderId: message.senderId,
    text: message.text,
    createdAt: message.createdAt,
  };
}
