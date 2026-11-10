import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Application, Post, User } from '@prisma/client';
import {
  ApplicationStatus,
  InvitationStatus,
  OrderStatus,
  PostOrigin,
  PostStatus,
  PostType,
  Role,
} from '../common/enums.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { assertVerified } from '../common/verification.util.js';
import { OrderDto, toOrderDto } from '../orders/order.mapper.js';
import { generateMeetCode } from '../common/meet-code.util.js';
import { PricingService } from '../pricing/pricing.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  ACTIVITY_DURATION_MINUTES,
  findTemplate,
  isWithinMeetingHours,
} from './activity-templates.js';
import { CreatePostDto } from './posts.dto.js';

type PostWithAuthor = Post & { author: User };
type ApplicationSlice = {
  applicantId: string;
  status: string;
  applicant: User;
};

export interface PostDto {
  id: string;
  author: PublicUser;
  /// DEMAND (transactional activity request) | MOMENT (community recap).
  type: string;
  sceneTag: string;
  title: string;
  description: string;
  detail: string;
  /// The platform template the post launched from; empty on moments.
  templateId: string;
  /// The concrete meeting time picked at publish; null on moments.
  scheduledAt: Date | null;
  /// District snapshot from the template; empty if unset.
  area: string;
  /// Partner venue resolved from the template, e.g. "Glorietta Mall".
  venueName: string;
  /// Exact meeting point resolved from the template.
  meetingPoint: string;
  /// Display label for the suggested duration, e.g. "建议 2–3 小时".
  durationLabel: string;
  /// Venue name on MOMENT recaps (empty on demand posts).
  venue: string;
  imageUrl: string;
  images: string[];
  applicantCount: number;
  /// Avatar URLs of the pending candidates (capped). Served to non-owner
  /// callers so they can gauge interest; no names or pitches leave the
  /// owner-only candidate endpoint.
  applicantAvatars: string[];
  status: string;
  feeMinor: number;
  /// Who covers on-site expenses: TREAT (publisher treats) | AA.
  expensePolicy: string;
  hasApplied: boolean;
  /// The host whose plan was approved; null while the post is still open.
  /// Drives the community card's "host accepted" attribution line.
  selectedHost: PublicUser | null;
  createdAt: Date;
}

export interface ApplicationDto {
  id: string;
  postId: string;
  applicant: PublicUser;
  status: string;
  createdAt: Date;
}

/// One pending sign-up on something the caller published: a candidate on
/// their demand post (APPLICATION) or an inviter on their pitch
/// (INVITATION). targetId opens the surface where the caller acts on it.
export interface SignupNoticeDto {
  id: string;
  kind: 'APPLICATION' | 'INVITATION';
  targetId: string;
  actor: PublicUser;
  createdAt: Date;
}

@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pricingService: PricingService,
  ) {}

  async create(author: User, input: CreatePostDto): Promise<PostDto> {
    assertVerified(author);
    // Activity requests come from the user side; hosts supply the plans.
    if (author.role === Role.host) {
      throw new ForbiddenException('Hosts cannot post activity requests');
    }
    // Template-only publishing: the platform fixes the whole activity
    // envelope (scene, cover, district, meeting point); the author only
    // brings words and a meeting time.
    const template = findTemplate(input.templateId);
    if (!template) {
      throw new NotFoundException('TEMPLATE_NOT_FOUND');
    }
    // Hosts work 09:00-22:00 Manila time; the activity must fit inside.
    const meetAt = new Date(input.scheduledAt);
    if (!isWithinMeetingHours(meetAt)) {
      throw new BadRequestException('MEET_TIME_OUT_OF_HOURS');
    }
    // The poster picks a platform-defined budget tier (middle tier when
    // unspecified); the snapshot keeps later repricing away from this post.
    const feeMinor = await this.pricingService.resolveBudget(
      template.sceneTag,
      input.budgetMinor,
    );
    const post = await this.prisma.post.create({
      data: {
        authorId: author.id,
        sceneTag: template.sceneTag,
        title: input.title,
        description: input.description ?? '',
        templateId: template.id,
        scheduledAt: meetAt,
        area: template.area,
        imageUrl: template.imageUrl,
        feeMinor,
        expensePolicy: input.expensePolicy ?? 'TREAT',
      },
      include: { author: true },
    });
    return this.toDto(post, []);
  }

  /// Community recap: photos + text about a completed activity. Open to
  /// both roles and never transactional (no fee, no sign-ups).
  async createMoment(
    author: User,
    text: string,
    images: string[],
    venue: string,
  ): Promise<PostDto> {
    assertVerified(author);
    const post = await this.prisma.post.create({
      data: {
        authorId: author.id,
        type: PostType.moment,
        sceneTag: '',
        title: text,
        description: text,
        imageUrl: images[0] ?? '',
        imagesJson: JSON.stringify(images),
        venue: venue.trim(),
        feeMinor: 0,
      },
      include: { author: true },
    });
    return this.toDto(post, []);
  }

  async feed(
    caller: User,
    scene?: string,
    authorId?: string,
    view?: string,
  ): Promise<PostDto[]> {
    // Two public surfaces plus two personal views:
    // - default (the community wall): sharing posts (moments) only; demand
    //   posts never show here.
    // - view=requests (the gig hall): demand posts in every live status.
    //   ROLE-ISOLATED: hosts see every user's requests (their work queue);
    //   users see only their own — same-side browsing is deliberately off
    //   (the hall trades services, it is not a bulletin board). Private
    //   invitation deals (DIRECT origin) are excluded at all times.
    // - view=applied: still-open demand posts the caller signed up for
    //   and is waiting on (the host's side of the activity board).
    // - authorId: that author's posts in every status.
    const posts = await this.prisma.post.findMany({
      where: {
        ...(authorId
          ? { authorId }
          : view === 'requests'
            ? {
                origin: PostOrigin.feed,
                type: PostType.demand,
                ...(caller.role === Role.host ? {} : { authorId: caller.id }),
                // Requests stay listed through their whole life —
                // selection, payment, even completion — so the hall
                // keeps showing activity. Only cancelled/deleted posts
                // drop out. (A time-based hiding window can come later.)
                status: { not: PostStatus.cancelled },
              }
            : view === 'applied'
              ? {
                  type: PostType.demand,
                  status: PostStatus.open,
                  applications: {
                    some: {
                      applicantId: caller.id,
                      status: ApplicationStatus.applied,
                    },
                  },
                }
              : { type: PostType.moment }),
        ...(scene ? { sceneTag: scene } : {}),
      },
      include: {
        author: true,
        applications: { include: { applicant: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return posts.map((post) => this.toDto(post, post.applications, caller));
  }

  async getOne(caller: User, postId: string): Promise<PostDto> {
    const post = await this.findPostOrThrow(postId);
    const applications = await this.prisma.application.findMany({
      where: { postId },
      include: { applicant: true },
    });
    return this.toDto(post, applications, caller);
  }

  /// Author-only soft delete. Allowed only while the post is OPEN: once a
  /// candidate was selected (an order exists) the date flow owns the money
  /// and its lifecycle, so the post can no longer be deleted.
  async remove(caller: User, postId: string): Promise<PostDto> {
    const post = await this.findPostOrThrow(postId);
    // The author retracts their own post; ADMIN takes down anyone's.
    if (post.authorId !== caller.id && caller.role !== Role.admin) {
      throw new ForbiddenException('Only the author can delete a post');
    }
    if (post.status !== PostStatus.open) {
      throw new ConflictException('Only open posts can be deleted');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      // Release pending candidates so their "applied" state does not point
      // at a dead post.
      await tx.application.updateMany({
        where: { postId, status: ApplicationStatus.applied },
        data: { status: ApplicationStatus.released },
      });
      return tx.post.update({
        where: { id: postId },
        data: { status: PostStatus.cancelled },
        include: { author: true },
      });
    });
    return this.toDto(updated, []);
  }

  /// Free one-tap sign-up into the candidate pool. Host accounts only
  /// (any gender): the marketplace sells activity hosting, not dates.
  /// The sign-up carries nothing — venue, meeting point, time and
  /// duration are all fixed by the template and the post, so selection
  /// is purely about the person.
  async apply(caller: User, postId: string): Promise<ApplicationDto> {
    assertVerified(caller);
    if (caller.role !== Role.host) {
      throw new ForbiddenException('Only hosts can sign up for activities');
    }
    const post = await this.findPostOrThrow(postId);
    if (post.type !== PostType.demand) {
      throw new ConflictException('Only activity requests take sign-ups');
    }
    if (post.status !== PostStatus.open) {
      throw new ConflictException('Post is not open for sign-ups');
    }
    if (post.authorId === caller.id) {
      throw new ConflictException('Cannot apply to your own post');
    }
    const existing = await this.prisma.application.findUnique({
      where: { postId_applicantId: { postId, applicantId: caller.id } },
    });
    if (existing) {
      throw new ConflictException('Already applied');
    }
    const application = await this.prisma.application.create({
      data: {
        postId,
        applicantId: caller.id,
      },
      include: { applicant: true },
    });
    return PostsService.toApplicationDto(application);
  }

  /// Pending sign-ups across everything the caller published: candidates
  /// queued on their open demand posts plus invitations queued on their
  /// open pitches. Feeds the hall's Moments-style unread pill — the
  /// client diffs against a locally stored last-seen timestamp, so the
  /// server stays stateless (no notifications table).
  async listSignupNotices(caller: User): Promise<SignupNoticeDto[]> {
    const [applications, invitations] = await Promise.all([
      this.prisma.application.findMany({
        where: {
          status: ApplicationStatus.applied,
          post: { authorId: caller.id, status: PostStatus.open },
        },
        include: { applicant: true },
      }),
      this.prisma.invitation.findMany({
        where: { hostId: caller.id, status: InvitationStatus.pending },
        include: { from: true },
      }),
    ]);
    // Guard against invites whose proposal already closed: PENDING rows
    // on a non-open pitch are stale, not actionable.
    const proposalIds = [...new Set(invitations.map((i) => i.proposalId))];
    const openProposals = await this.prisma.proposal.findMany({
      where: { id: { in: proposalIds }, status: PostStatus.open },
      select: { id: true },
    });
    const openIds = new Set(openProposals.map((p) => p.id));
    const notices: SignupNoticeDto[] = [
      ...applications.map((a) => ({
        id: a.id,
        kind: 'APPLICATION' as const,
        targetId: a.postId,
        actor: toPublicUser(a.applicant),
        createdAt: a.createdAt,
      })),
      ...invitations
        .filter((i) => openIds.has(i.proposalId))
        .map((i) => ({
          id: i.id,
          kind: 'INVITATION' as const,
          targetId: i.proposalId,
          actor: toPublicUser(i.from),
          createdAt: i.createdAt,
        })),
    ];
    return notices.sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
    );
  }

  async listApplications(
    caller: User,
    postId: string,
  ): Promise<ApplicationDto[]> {
    const post = await this.findPostOrThrow(postId);
    if (post.authorId !== caller.id) {
      throw new ForbiddenException('Only the author sees the candidate pool');
    }
    const applications = await this.prisma.application.findMany({
      where: { postId, status: { not: ApplicationStatus.released } },
      include: { applicant: true },
      orderBy: { createdAt: 'asc' },
    });
    return applications.map((a) => PostsService.toApplicationDto(a));
  }

  /// The poster approves one candidate. Creates the order AWAITING_PAYMENT;
  /// the payer is ALWAYS the poster (business rule). The fee split is
  /// snapshotted here with the current commission rate.
  async select(
    caller: User,
    postId: string,
    applicationId: string,
  ): Promise<OrderDto> {
    const post = await this.findPostOrThrow(postId);
    if (post.authorId !== caller.id) {
      throw new ForbiddenException('Only the author can select a candidate');
    }
    if (post.status !== PostStatus.open) {
      throw new ConflictException('Post is not open for selection');
    }
    const application = await this.prisma.application.findUnique({
      where: { id: applicationId },
      include: { applicant: true },
    });
    if (!application || application.postId !== postId) {
      throw new NotFoundException('Application not found for this post');
    }
    if (application.status !== ApplicationStatus.applied) {
      throw new ConflictException('Candidate is no longer available');
    }

    // The poster requested the activity, so the poster always pays; the
    // selected host always earns the service fee (minus commission).
    const payer = post.author;
    const earner = application.applicant;
    const split = await this.pricingService.splitFee(post.feeMinor);

    // The plan is the template's meeting point plus the post's meeting
    // time: locked at publish, never negotiated. The order is born with
    // the plan confirmed, so chat opens the moment the payment lands.
    const template = findTemplate(post.templateId);
    const planPlace = template?.meetingPoint ?? '';
    const planAt = post.scheduledAt;

    const order = await this.prisma.$transaction(async (tx) => {
      // Atomic claim: flipping OPEN -> PENDING_PAYMENT is the mutex that
      // defeats two racing selections — the loser matches zero rows and
      // the whole transaction rolls back.
      const claimed = await tx.post.updateMany({
        where: { id: postId, status: PostStatus.open },
        data: { status: PostStatus.pendingPayment },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Post is not open for selection');
      }
      const picked = await tx.application.updateMany({
        where: { id: applicationId, status: ApplicationStatus.applied },
        data: { status: ApplicationStatus.selected },
      });
      if (picked.count === 0) {
        throw new ConflictException('Candidate is no longer available');
      }
      const planApproved = new Date();
      const created = await tx.order.create({
        data: {
          postId,
          payerId: payer.id,
          earnerId: earner.id,
          status: OrderStatus.awaitingPayment,
          feeMinor: split.feeMinor,
          commissionMinor: split.commissionMinor,
          netMinor: split.netMinor,
          meetCode: generateMeetCode(),
          ...(planPlace !== '' && planAt !== null
            ? {
                planPlace,
                planAt,
                planDurationMinutes: ACTIVITY_DURATION_MINUTES,
                planProposedAt: planApproved,
                planConfirmedAt: planApproved,
              }
            : {}),
        },
        include: { payer: true, earner: true, post: true },
      });
      if (planPlace !== '' && planAt !== null) {
        // The locked plan card opens the conversation as its first
        // message, visible as soon as the payment unlocks the chat.
        await tx.message.create({
          data: {
            orderId: created.id,
            senderId: earner.id,
            kind: 'PLAN',
            text: JSON.stringify({
              place: planPlace,
              scheduledAt: planAt.toISOString(),
              durationMinutes: ACTIVITY_DURATION_MINUTES,
              note: '',
            }),
          },
        });
      }
      return created;
    });
    // The caller is the payer: the one party allowed to see the meet code.
    return toOrderDto(order, caller.id);
  }

  private async findPostOrThrow(postId: string): Promise<PostWithAuthor> {
    const post = await this.prisma.post.findUnique({
      where: { id: postId },
      include: { author: true },
    });
    if (!post) {
      throw new NotFoundException('Post not found');
    }
    return post;
  }

  private toDto(
    post: PostWithAuthor,
    applications: ApplicationSlice[],
    caller?: User,
  ): PostDto {
    const callerId = caller?.id ?? '';
    const selected = applications.find(
      (a) => a.status === ApplicationStatus.selected,
    );
    // Candidate visibility: the owner gets the full pool elsewhere;
    // everyone else only sees anonymous avatars (interest gauge).
    const isOwner = callerId === post.authorId;
    const pending = applications.filter(
      (a) => a.status !== ApplicationStatus.released,
    );
    const template = findTemplate(post.templateId);
    return {
      id: post.id,
      author: toPublicUser(post.author),
      type: post.type,
      sceneTag: post.sceneTag,
      title: post.title,
      description: post.description,
      detail: post.detail,
      templateId: post.templateId,
      scheduledAt: post.scheduledAt,
      area: post.area,
      venueName: template?.venueName ?? '',
      meetingPoint: template?.meetingPoint ?? '',
      durationLabel: template?.durationLabel ?? '',
      venue: post.venue,
      imageUrl: post.imageUrl,
      images: PostsService.parseImages(post.imagesJson),
      applicantCount: pending.length,
      applicantAvatars: !isOwner
        ? pending.slice(0, 5).map((a) => a.applicant.avatarUrl)
        : [],
      status: post.status,
      feeMinor: post.feeMinor,
      expensePolicy: post.expensePolicy,
      hasApplied: applications.some((a) => a.applicantId === callerId),
      selectedHost: selected ? toPublicUser(selected.applicant) : null,
      createdAt: post.createdAt,
    };
  }

  private static parseImages(json: string): string[] {
    try {
      const parsed: unknown = JSON.parse(json);
      return Array.isArray(parsed)
        ? parsed.filter((p): p is string => typeof p === 'string')
        : [];
    } catch {
      return [];
    }
  }

  private static toApplicationDto(
    application: Application & { applicant: User },
  ): ApplicationDto {
    return {
      id: application.id,
      postId: application.postId,
      applicant: toPublicUser(application.applicant),
      status: application.status,
      createdAt: application.createdAt,
    };
  }
}
