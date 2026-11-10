// Domain enums. Stored as strings because SQLite has no native enums; the
// PostgreSQL migration tightens these into DB enums with identical values.

export const Gender = {
  male: 'MALE',
  female: 'FEMALE',
} as const;
export type Gender = (typeof Gender)[keyof typeof Gender];

// A user's invitation on a host's proposal: PENDING until the host picks
// it (ACCEPTED). Mirrors ApplicationStatus on the demand side.
export const InvitationStatus = {
  pending: 'PENDING',
  accepted: 'ACCEPTED',
} as const;
export type InvitationStatus =
  (typeof InvitationStatus)[keyof typeof InvitationStatus];

export const VerificationStatus = {
  none: 'NONE',
  pending: 'PENDING',
  verified: 'VERIFIED',
} as const;

// Account roles are fixed at registration: USER posts activity requests
// and pays; HOST signs up to host them and earns. ADMIN is internal.
export const Role = {
  user: 'USER',
  host: 'HOST',
  admin: 'ADMIN',
} as const;
export type Role = (typeof Role)[keyof typeof Role];

/// Roles selectable at registration (ADMIN is never self-service).
export const RegistrableRoles = [Role.user, Role.host] as const;

// Account standing. BANNED accounts fail every authenticated request at
// the guard, so a ban takes effect on the victim's very next tap.
export const UserStatus = {
  active: 'ACTIVE',
  banned: 'BANNED',
} as const;
export type UserStatus = (typeof UserStatus)[keyof typeof UserStatus];

// In-room safety reports: OPEN holds the order's settlement until ops
// resolves it one way or the other.
export const ReportStatus = {
  open: 'OPEN',
  resolved: 'RESOLVED',
} as const;
export type ReportStatus = (typeof ReportStatus)[keyof typeof ReportStatus];

export const PostOrigin = {
  feed: 'FEED',
  direct: 'DIRECT',
} as const;
export type PostOrigin = (typeof PostOrigin)[keyof typeof PostOrigin];

export const PostType = {
  demand: 'DEMAND',
  moment: 'MOMENT',
} as const;
export type PostType = (typeof PostType)[keyof typeof PostType];

export const PostStatus = {
  open: 'OPEN',
  pendingPayment: 'PENDING_PAYMENT',
  matched: 'MATCHED',
  completed: 'COMPLETED',
  cancelled: 'CANCELLED',
} as const;
export type PostStatus = (typeof PostStatus)[keyof typeof PostStatus];

export const ApplicationStatus = {
  applied: 'APPLIED',
  selected: 'SELECTED',
  released: 'RELEASED',
} as const;
export type ApplicationStatus =
  (typeof ApplicationStatus)[keyof typeof ApplicationStatus];

export const OrderStatus = {
  awaitingPayment: 'AWAITING_PAYMENT',
  active: 'ACTIVE',
  completed: 'COMPLETED',
  cancelled: 'CANCELLED',
  // Nobody submitted the meet code in time: the escrow goes to neither
  // side (platform keeps it; extreme cases are handled manually).
  forfeited: 'FORFEITED',
} as const;
export type OrderStatus = (typeof OrderStatus)[keyof typeof OrderStatus];

export const PaymentStatus = {
  succeeded: 'SUCCEEDED',
  refunded: 'REFUNDED',
} as const;
export type PaymentStatus = (typeof PaymentStatus)[keyof typeof PaymentStatus];

export const LedgerAccount = {
  platformEscrow: 'PLATFORM_ESCROW',
  platformRevenue: 'PLATFORM_REVENUE',
  userWallet: 'USER_WALLET',
} as const;
export type LedgerAccount = (typeof LedgerAccount)[keyof typeof LedgerAccount];

export const LedgerEntryType = {
  escrowIn: 'ESCROW_IN',
  escrowRelease: 'ESCROW_RELEASE',
  escrowRefund: 'ESCROW_REFUND',
  settleNet: 'SETTLE_NET',
  settleCommission: 'SETTLE_COMMISSION',
  escrowForfeit: 'ESCROW_FORFEIT',
  withdrawal: 'WITHDRAWAL',
} as const;
export type LedgerEntryType =
  (typeof LedgerEntryType)[keyof typeof LedgerEntryType];

export const WithdrawalStatus = {
  pending: 'PENDING',
  paid: 'PAID',
} as const;
export type WithdrawalStatus =
  (typeof WithdrawalStatus)[keyof typeof WithdrawalStatus];
