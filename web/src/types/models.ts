// Domain models. All money fields are whole pesos (converted from server
// minor units at the API boundary).

export interface PostAuthor {
  id: string;
  name: string;
  avatarUrl: string;
  /** Short display meta, e.g. "Female · 24". */
  meta: string;
  isVerified: boolean;
}

/**
 * One pending sign-up on something I published: a candidate on my demand
 * post (APPLICATION) or an inviter on my pitch (INVITATION). Backs the
 * hall's Moments-style unread pill.
 */
export interface SignupNotice {
  id: string;
  kind: 'APPLICATION' | 'INVITATION';
  targetId: string;
  actor: PostAuthor;
  createdAt: Date;
}

export type PostStatus =
  | 'OPEN'
  | 'PENDING_PAYMENT'
  | 'MATCHED'
  | 'COMPLETED'
  | 'CANCELLED';

export interface ActivityPost {
  id: string;
  /** DEMAND (transactional activity request) | MOMENT (community recap). */
  type: 'DEMAND' | 'MOMENT';
  sceneTag: string;
  title: string;
  description: string;
  detail: string;
  /** The platform template the post launched from; empty on moments. */
  templateId: string;
  /** The concrete meeting time picked at publish; null on moments. */
  scheduledAt: Date | null;
  area: string;
  /** Partner venue resolved from the template, e.g. "Glorietta Mall". */
  venueName: string;
  /** Exact meeting point resolved from the template. */
  meetingPoint: string;
  /** Suggested duration label resolved from the template. */
  durationLabel: string;
  venue: string;
  signedCount: number;
  applicantAvatars: string[];
  imageUrl: string;
  images: string[];
  author: PostAuthor;
  createdAt: Date;
  /** Platform-set service fee (whole pesos) for this scene. */
  budgetAmount: number;
  /** Who covers on-site expenses: TREAT (publisher treats) | AA. */
  expensePolicy: 'TREAT' | 'AA';
  hasApplied: boolean;
  status: PostStatus;
  selectedHost: PostAuthor | null;
}

export interface Candidate {
  applicationId: string;
  author: PostAuthor;
}

export type OrderStatus =
  | 'AWAITING_PAYMENT'
  | 'ACTIVE'
  | 'COMPLETED'
  | 'CANCELLED'
  | 'FORFEITED';

export interface LiveOrder {
  id: string;
  postId: string;
  payer: PostAuthor;
  earner: PostAuthor;
  status: OrderStatus;
  feeAmount: number;
  commissionAmount: number;
  netAmount: number;
  /** Disclosed once the fee is escrowed (empty before that). */
  payerPhone: string;
  earnerPhone: string;
  postTitle: string;
  postImageUrl: string;
  /** Effective venue and time: set once the plan is confirmed. */
  scheduledAt: Date | null;
  place: string;
  placeLat: number;
  placeLng: number;
  planPlace: string;
  planLat: number;
  planLng: number;
  planAt: Date | null;
  planNote: string;
  planDurationMinutes: number;
  planProposedAt: Date | null;
  planConfirmedAt: Date | null;
  /** Proof-of-meeting code, served ONLY to the payer. */
  meetCode: string;
  startedAt: Date | null;
  cancellableUntil: Date | null;
  completedAt: Date | null;
  /** Whether I ever opened this order's chat room. */
  viewerEnteredRoom: boolean;
  createdAt: Date;
}

export interface OrderMessage {
  id: string;
  senderId: string;
  /**
   * TEXT for plain chat; PLAN carries the plan JSON snapshot; REQUEST
   * carries a rebooking card (see ActivityRequestCard).
   */
  kind: 'TEXT' | 'PLAN' | 'REQUEST';
  text: string;
  createdAt: Date;
}

/**
 * One row of the contact-style conversation list: a partner the user
 * has (or had) a deal with, plus a preview of the newest message across
 * all shared orders. The row opens into [roomOrderId]'s room.
 */
export interface ConversationItem {
  peerId: string;
  peerName: string;
  peerAvatarUrl: string;
  peerVerified: boolean;
  roomOrderId: string;
  /** True when a deal with this partner is currently running. */
  hasLiveOrder: boolean;
  lastMessageKind: string;
  lastMessageText: string;
  lastMessageAt: Date | null;
  /** Partner messages I have not read yet, across all shared orders. */
  unreadCount: number;
  sortedAt: Date;
}

/**
 * The parsed payload of a REQUEST chat message: a rebooking card the
 * payer sends to the host inside an existing conversation. Accepting it
 * creates a brand-new order referenced by [orderId].
 */
export interface ActivityRequestCard {
  templateId: string;
  title: string;
  meetingPoint: string;
  scheduledAt: Date;
  /** The picked price tier, whole currency units. */
  amount: number;
  note: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED';
  orderId: string;
}

export interface ProposalCard {
  id: string;
  title: string;
  description: string;
  sceneTag: string;
  imageUrl: string;
  /** The platform template the pitch launched from. */
  templateId: string;
  /**
   * The host's rough availability window (ANYTIME | NOON | EVENING): the
   * pitch is a service shelf listing, and inviters pick the concrete
   * time (and price tier) inside it.
   */
  timeSlot: string;
  area: string;
  /** Partner venue resolved from the template. */
  venueName: string;
  /** Exact meeting point resolved from the template. */
  meetingPoint: string;
  /** Suggested duration label resolved from the template. */
  durationLabel: string;
  status: PostStatus;
  inviteCount: number;
  hasInvited: boolean;
  createdAt: Date;
  hostId: string;
  hostName: string;
  hostAvatarUrl: string;
  hostMeta: string;
  hostCity: string;
  hostIsVerified: boolean;
  hostCompletedActivities: number;
}

export interface InvitationRecord {
  id: string;
  proposalId: string;
  note: string;
  /** PENDING | ACCEPTED */
  status: string;
  /** The concrete meeting time the inviter picked. */
  scheduledAt: Date | null;
  /** The price tier the inviter picked (whole currency units). */
  amount: number;
  fromId: string;
  fromName: string;
  fromAvatarUrl: string;
  fromMeta: string;
  fromVerified: boolean;
  createdAt: Date;
}

export interface HostCard {
  id: string;
  name: string;
  avatarUrl: string;
  meta: string;
  isVerified: boolean;
  bio: string;
  city: string;
  tags: string[];
  completedActivities: number;
  recentProposals: string[];
}

export interface ProfileStat {
  value: string;
  label: string;
}

export interface ProfileInfoItem {
  label: string;
  value: string;
}

export interface CurrentUser {
  id: string;
  name: string;
  gender: string;
  avatarUrl: string;
  meta: string;
  isVerified: boolean;
  /** Display line under the name, e.g. "Meeto ID 20481 · 武汉". */
  idLine: string;
  stats: ProfileStat[];
}

export interface UserDetail {
  id: string;
  name: string;
  avatarUrl: string;
  meta: string;
  isVerified: boolean;
  city: string;
  joinedText: string;
  bio: string;
  tags: string[];
  photos: string[];
  info: ProfileInfoItem[];
  stats: ProfileStat[];
}

export interface WalletSummary {
  monthIncome: number;
  withdrawable: number;
}

export interface WithdrawalRecord {
  id: string;
  amount: number;
  /** PENDING | PAID */
  status: string;
  createdAt: Date;
}

/**
 * A curated activity template — the only publish path. The platform fixes
 * the whole activity envelope (scene, cover, district, partner venue and
 * meeting point); publishers only bring words and a meeting time. The
 * budget is not stored here — it is the platform scene fee, resolved from
 * pricing at display time.
 */
export interface ActivityTemplate {
  id: string;
  sceneTag: string;
  title: string;
  description: string;
  imageUrl: string;
  /** Display label for the suggested duration, e.g. "约 2 小时". */
  durationLabel: string;
  /** Partner venue, e.g. "Glorietta Mall". */
  venueName: string;
  /** Exact meeting point inside the venue. */
  meetingPoint: string;
  /** City district, e.g. "Makati". */
  area: string;
}

export interface PlaceSuggestion {
  name: string;
  address: string;
}

export interface PricingConfig {
  platformFeeRate: number;
  sceneBudgetTiers: Record<string, number[]>;
  defaultFee: number;
}
