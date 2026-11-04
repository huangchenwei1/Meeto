import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { Application, Post, User } from '@prisma/client';
import {
  ApplicationStatus,
  NotificationType,
  OrderStatus,
  PostOrigin,
  PostStatus,
  PostType,
  Role,
} from '../common/enums.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { assertVerified } from '../common/verification.util.js';
import { NotificationsService } from '../notifications/notifications.module.js';
import { OrderDto, toOrderDto } from '../orders/order.mapper.js';
import { generateMeetCode } from '../common/meet-code.util.js';
import { PricingService } from '../pricing/pricing.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { ApplyDto, CreatePostDto } from './posts.dto.js';

type PostWithAuthor = Post & { author: User };
type ApplicationSlice = {
  applicantId: string;
  status: string;
  proposal: string;
  applicant: User;
};

export interface ApplicantPreview {
  avatarUrl: string;
  /// First characters of the host's pitch, truncated server-side so the
  /// full text never leaves the owner-only candidate endpoint.
  proposalTeaser: string;
}

export interface PostDto {
  id: string;
  author: PublicUser;
  /// DEMAND (transactional activity request) | MOMENT (community recap).
  type: string;
  sceneTag: string;
  title: string;
  description: string;
  detail: string;
  /// Fuzzy availability window identifier (e.g. TONIGHT); empty if unset.
  timeSlot: string;
  /// Rough district picked at publish time; empty if unset.
  area: string;
  /// Venue name on MOMENT recaps (empty on demand posts).
  venue: string;
  imageUrl: string;
  images: string[];
  applicantCount: number;
  /// Avatar URLs of the pending candidates (capped). Served to HOST
  /// callers only: hosts may gauge competition but never see rival
  /// pitches; the client renders these blurred.
  applicantAvatars: string[];
  /// Candidate previews served to USER callers (non-owner): a clear
  /// avatar plus the first few characters of the pitch. No names or
  /// ids — teasing the service, not exposing the pool.
  applicantPreviews: ApplicantPreview[];
  status: string;
  feeMinor: number;
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
  /// The host's one-line plan pitch written at sign-up.
  proposal: string;
  /// The structured plan card delivered at sign-up: venue...
  planPlace: string;
  planDurationMinutes: number;
  /// ...and time. Selection approves this plan.
  planAt: Date | null;
  createdAt: Date;
}

@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly pricingService: PricingService,
    private readonly notifications: NotificationsService,
  ) {}

  async create(author: User, input: CreatePostDto): Promise<PostDto> {
    assertVerified(author);
    // Activity requests come from the user side; hosts supply the plans.
    if (author.role === Role.host) {
      throw new ForbiddenException('Hosts cannot post activity requests');
    }
    // The poster picks a platform-defined budget tier (middle tier when
    // unspecified); the snapshot keeps later repricing away from this post.
    const feeMinor = await this.pricingService.resolveBudget(
      input.sceneTag,
      input.budgetMinor,
    );
    const post = await this.prisma.post.create({
      data: {
        authorId: author.id,
        sceneTag: input.sceneTag,
        title: input.title,
        description: input.description ?? '',
        detail: input.detail ?? '',
        timeSlot: input.timeSlot ?? '',
        area: input.area ?? '',
        imageUrl: input.imageUrl ?? '',
        feeMinor,
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
    // Two public surfaces plus the author's own management view:
    // - default (the community wall): sharing posts (moments) only; demand
    //   posts never show here.
    // - view=requests (the host gig hall): OPEN demand posts hosts can
    //   still pitch on. Private invitation deals (DIRECT origin) are
    //   excluded at all times.
    // - authorId: that author's posts in every status.
    const posts = await this.prisma.post.findMany({
      where: {
        ...(authorId
          ? { authorId }
          : view === 'requests'
            ? {
                origin: PostOrigin.feed,
                type: PostType.demand,
                // Requests stay listed through their whole life —
                // selection, payment, even completion — so the hall
                // keeps showing activity. Only cancelled/deleted posts
                // drop out. (A time-based hiding window can come later.)
                status: { not: PostStatus.cancelled },
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
    if (post.authorId !== caller.id) {
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

  /// Free sign-up into the candidate pool. Host accounts only (any gender):
  /// the marketplace sells activity hosting, not dates. The sign-up carries
  /// the structured plan card (place + time): selection approves the plan.
  async apply(
    caller: User,
    postId: string,
    input: ApplyDto,
  ): Promise<ApplicationDto> {
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
        proposal: input.proposal,
        planPlace: input.place,
        planAt: new Date(input.scheduledAt),
        planDurationMinutes: input.durationMinutes,
      },
      include: { applicant: true },
    });
    await this.notifications.notify(this.prisma, {
      userId: post.authorId,
      type: NotificationType.newApplicant,
      actorName: caller.name,
      actorAvatarUrl: caller.avatarUrl,
      postId,
    });
    return PostsService.toApplicationDto(application);
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

    const order = await this.prisma.$transaction(async (tx) => {
      await tx.application.update({
        where: { id: applicationId },
        data: { status: ApplicationStatus.selected },
      });
      await tx.post.update({
        where: { id: postId },
        data: { status: PostStatus.pendingPayment },
      });
      // Selecting the candidate approves the plan card delivered at
      // sign-up: the order starts with the plan proposed and confirmed, so
      // chat opens the moment the payment lands.
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
          ...(application.planPlace !== '' && application.planAt !== null
            ? {
                planPlace: application.planPlace,
                planAt: application.planAt,
                planDurationMinutes: application.planDurationMinutes,
                // The sign-up pitch doubles as the itinerary.
                planNote: application.proposal,
                planProposedAt: planApproved,
                planConfirmedAt: planApproved,
              }
            : {}),
        },
        include: { payer: true, earner: true, post: true },
      });
      if (application.planPlace !== '' && application.planAt !== null) {
        // The approved plan card opens the conversation as its first
        // message, visible as soon as the payment unlocks the chat.
        await tx.message.create({
          data: {
            orderId: created.id,
            senderId: earner.id,
            kind: 'PLAN',
            text: JSON.stringify({
              place: application.planPlace,
              scheduledAt: application.planAt.toISOString(),
              durationMinutes: application.planDurationMinutes,
              note: application.proposal,
            }),
          },
        });
      }
      await this.notifications.notify(tx, {
        userId: application.applicantId,
        type: NotificationType.selected,
        actorName: caller.name,
        actorAvatarUrl: caller.avatarUrl,
        postId,
        orderId: created.id,
      });
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
    // Candidate visibility is trimmed by viewer role: the owner gets the
    // full pool elsewhere, hosts get anonymous avatars (competition
    // gauge), users get avatar + pitch teaser (service showcase).
    const isOwner = callerId === post.authorId;
    const pending = applications.filter(
      (a) => a.status !== ApplicationStatus.released,
    );
    const forHost = !isOwner && caller?.role === Role.host;
    const forUser = !isOwner && !!caller && caller.role !== Role.host;
    return {
      id: post.id,
      author: toPublicUser(post.author),
      type: post.type,
      sceneTag: post.sceneTag,
      title: post.title,
      description: post.description,
      detail: post.detail,
      timeSlot: post.timeSlot,
      area: post.area,
      venue: post.venue,
      imageUrl: post.imageUrl,
      images: PostsService.parseImages(post.imagesJson),
      applicantCount: pending.length,
      applicantAvatars: forHost
        ? pending.slice(0, 5).map((a) => a.applicant.avatarUrl)
        : [],
      applicantPreviews: forUser
        ? pending.slice(0, 5).map((a) => ({
            avatarUrl: a.applicant.avatarUrl,
            proposalTeaser: PostsService.teaser(a.proposal),
          }))
        : [],
      status: post.status,
      feeMinor: post.feeMinor,
      hasApplied: applications.some((a) => a.applicantId === callerId),
      selectedHost: selected ? toPublicUser(selected.applicant) : null,
      createdAt: post.createdAt,
    };
  }

  private static teaser(proposal: string): string {
    const trimmed = proposal.trim();
    return trimmed.length <= 12 ? trimmed : `${trimmed.slice(0, 12)}\u2026`;
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
      proposal: application.proposal,
      planPlace: application.planPlace,
      planAt: application.planAt,
      planDurationMinutes: application.planDurationMinutes,
      createdAt: application.createdAt,
    };
  }
}
