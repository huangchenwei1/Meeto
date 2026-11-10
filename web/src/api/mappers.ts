import { minorToMajor, parseDate, resolveMediaUrl } from '@/api/client';
import { sceneImageFor } from '@/constants/sceneImages';
import type {
  ActivityPost,
  HostCard,
  InvitationRecord,
  LiveOrder,
  ActivityRequestCard,
  ConversationItem,
  OrderMessage,
  PostAuthor,
  PostStatus,
  ProposalCard,
} from '@/types/models';

type Json = Record<string, unknown>;

export function toAuthor(json: Json): PostAuthor {
  return {
    id: json.id as string,
    name: json.name as string,
    avatarUrl: resolveMediaUrl((json.avatarUrl as string) ?? ''),
    meta: (json.meta as string) ?? '',
    isVerified: (json.isVerified as boolean) ?? false,
  };
}

export function toActivityPost(json: Json): ActivityPost {
  const sceneTag = json.sceneTag as string;
  const imageUrl = (json.imageUrl as string) ?? '';
  const type = ((json.type as string) ?? 'DEMAND') as 'DEMAND' | 'MOMENT';
  const description = (json.description as string) ?? '';
  const detail = (json.detail as string) ?? '';
  return {
    id: json.id as string,
    type,
    sceneTag,
    title: json.title as string,
    description,
    detail: detail.length === 0 ? description : detail,
    templateId: (json.templateId as string) ?? '',
    scheduledAt: parseDate(json.scheduledAt),
    area: (json.area as string) ?? '',
    venueName: (json.venueName as string) ?? '',
    meetingPoint: (json.meetingPoint as string) ?? '',
    durationLabel: (json.durationLabel as string) ?? '',
    venue: (json.venue as string) ?? '',
    signedCount: (json.applicantCount as number) ?? 0,
    applicantAvatars: ((json.applicantAvatars as string[]) ?? []).map(
      resolveMediaUrl,
    ),
    // Demand cards fall back to the scene image; moments keep whatever
    // photos the author attached (possibly none).
    imageUrl:
      imageUrl.length === 0 && type === 'DEMAND'
        ? sceneImageFor(sceneTag)
        : resolveMediaUrl(imageUrl),
    images: ((json.images as string[]) ?? []).map(resolveMediaUrl),
    author: toAuthor(json.author as Json),
    createdAt: new Date(json.createdAt as string),
    budgetAmount: minorToMajor(json.feeMinor as number),
    expensePolicy: ((json.expensePolicy as string) ?? 'TREAT') as
      | 'TREAT'
      | 'AA',
    hasApplied: (json.hasApplied as boolean) ?? false,
    status: ((json.status as string) ?? 'OPEN') as PostStatus,
    selectedHost:
      json.selectedHost == null ? null : toAuthor(json.selectedHost as Json),
  };
}

export function toLiveOrder(json: Json): LiveOrder {
  return {
    id: json.id as string,
    postId: json.postId as string,
    payer: toAuthor(json.payer as Json),
    earner: toAuthor(json.earner as Json),
    status: json.status as LiveOrder['status'],
    feeAmount: minorToMajor(json.feeMinor as number),
    commissionAmount: minorToMajor(json.commissionMinor as number),
    netAmount: minorToMajor(json.netMinor as number),
    payerPhone: (json.payerPhone as string) ?? '',
    earnerPhone: (json.earnerPhone as string) ?? '',
    postTitle: (json.postTitle as string) ?? '',
    postImageUrl: resolveMediaUrl((json.postImageUrl as string) ?? ''),
    scheduledAt: parseDate(json.scheduledAt),
    place: (json.place as string) ?? '',
    placeLat: (json.placeLat as number) ?? 0,
    placeLng: (json.placeLng as number) ?? 0,
    planPlace: (json.planPlace as string) ?? '',
    planLat: (json.planLat as number) ?? 0,
    planLng: (json.planLng as number) ?? 0,
    planAt: parseDate(json.planAt),
    planNote: (json.planNote as string) ?? '',
    planDurationMinutes: (json.planDurationMinutes as number) ?? 0,
    planProposedAt: parseDate(json.planProposedAt),
    planConfirmedAt: parseDate(json.planConfirmedAt),
    meetCode: (json.meetCode as string) ?? '',
    startedAt: parseDate(json.startedAt),
    cancellableUntil: parseDate(json.cancellableUntil),
    completedAt: parseDate(json.completedAt),
    viewerEnteredRoom: (json.viewerEnteredRoom as boolean) ?? false,
    createdAt: new Date(json.createdAt as string),
  };
}

export function toOrderMessage(json: Json): OrderMessage {
  return {
    id: json.id as string,
    senderId: json.senderId as string,
    kind: ((json.kind as string) ?? 'TEXT') as OrderMessage['kind'],
    text: json.text as string,
    createdAt: new Date(json.createdAt as string),
  };
}

export function toConversation(json: Json): ConversationItem {
  const peer = json.peer as Json;
  return {
    peerId: peer.id as string,
    peerName: peer.name as string,
    peerAvatarUrl: resolveMediaUrl((peer.avatarUrl as string) ?? ''),
    peerVerified: (peer.isVerified as boolean) ?? false,
    roomOrderId: json.roomOrderId as string,
    hasLiveOrder: (json.hasLiveOrder as boolean) ?? false,
    lastMessageKind: (json.lastMessageKind as string) ?? '',
    lastMessageText: (json.lastMessageText as string) ?? '',
    lastMessageAt: parseDate(json.lastMessageAt),
    unreadCount: (json.unreadCount as number) ?? 0,
    sortedAt: new Date(json.sortedAt as string),
  };
}

/** Parses the rebooking card carried by a REQUEST chat message. */
export function parseActivityRequest(
  message: OrderMessage,
): ActivityRequestCard {
  const json = JSON.parse(message.text) as Json;
  return {
    templateId: (json.templateId as string) ?? '',
    title: (json.title as string) ?? '',
    meetingPoint: (json.meetingPoint as string) ?? '',
    scheduledAt: new Date(json.scheduledAt as string),
    amount: minorToMajor((json.budgetMinor as number) ?? 0),
    note: (json.note as string) ?? '',
    status: ((json.status as string) ??
      'PENDING') as ActivityRequestCard['status'],
    orderId: (json.orderId as string) ?? '',
  };
}

export function toProposalCard(json: Json): ProposalCard {
  const host = json.host as Json;
  return {
    id: json.id as string,
    title: json.title as string,
    description: (json.description as string) ?? '',
    sceneTag: json.sceneTag as string,
    imageUrl: resolveMediaUrl((json.imageUrl as string) ?? ''),
    templateId: (json.templateId as string) ?? '',
    timeSlot: (json.timeSlot as string) ?? 'ANYTIME',
    area: (json.area as string) ?? '',
    venueName: (json.venueName as string) ?? '',
    meetingPoint: (json.meetingPoint as string) ?? '',
    durationLabel: (json.durationLabel as string) ?? '',
    status: ((json.status as string) ?? 'OPEN') as PostStatus,
    inviteCount: (json.inviteCount as number) ?? 0,
    hasInvited: (json.hasInvited as boolean) ?? false,
    createdAt: new Date(json.createdAt as string),
    hostId: host.id as string,
    hostName: host.name as string,
    hostAvatarUrl: resolveMediaUrl((host.avatarUrl as string) ?? ''),
    hostMeta: (host.meta as string) ?? '',
    hostCity: (host.city as string) ?? '',
    hostIsVerified: (host.isVerified as boolean) ?? false,
    hostCompletedActivities: (json.hostCompletedActivities as number) ?? 0,
  };
}

/** The feed cover: the uploaded photo, or the scene default. */
export function proposalCoverUrl(proposal: ProposalCard): string {
  return proposal.imageUrl.length > 0
    ? proposal.imageUrl
    : sceneImageFor(proposal.sceneTag);
}

export function toInvitation(json: Json): InvitationRecord {
  const from = json.from as Json;
  return {
    id: json.id as string,
    proposalId: (json.proposalId as string) ?? '',
    note: (json.note as string) ?? '',
    status: json.status as string,
    scheduledAt: parseDate(json.scheduledAt),
    amount: minorToMajor((json.budgetMinor as number) ?? 0),
    fromId: from.id as string,
    fromName: from.name as string,
    fromAvatarUrl: resolveMediaUrl((from.avatarUrl as string) ?? ''),
    fromMeta: (from.meta as string) ?? '',
    fromVerified: (from.isVerified as boolean) ?? false,
    createdAt: new Date(json.createdAt as string),
  };
}

export function toHostCard(json: Json): HostCard {
  const user = json.user as Json;
  return {
    id: user.id as string,
    name: user.name as string,
    avatarUrl: resolveMediaUrl((user.avatarUrl as string) ?? ''),
    meta: (user.meta as string) ?? '',
    isVerified: (user.isVerified as boolean) ?? false,
    bio: (user.bio as string) ?? '',
    city: (user.city as string) ?? '',
    tags: (user.tags as string[]) ?? [],
    completedActivities: (json.completedActivities as number) ?? 0,
    recentProposals: (json.recentProposals as string[]) ?? [],
  };
}
