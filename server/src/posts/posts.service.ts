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
import { PricingService } from '../pricing/pricing.service.js';
import { PrismaService } from '../prisma/prisma.service.js';
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
  /// Fuzzy availability window identifier (e.g. TONIGHT); empty if unset.
  timeSlot: string;
  /// Rough district picked at publish time; empty if unset.
  area: string;
  /// Venue name on MOMENT recaps (empty on demand posts).
  venue: string;
  imageUrl: string;
  images: string[];
  applicantCount: number;
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
    // Snapshot the platform fee so later repricing never affects this post.
    const feeMinor = await this.pricingService.feeForScene(input.sceneTag);
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
                status: PostStatus.open,
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
    return posts.map((post) =>
      this.toDto(post, post.applications, caller.id),
    );
  }

  async getOne(caller: User, postId: string): Promise<PostDto> {
    const post = await this.findPostOrThrow(postId);
    const applications = await this.prisma.application.findMany({
      where: { postId },
      include: { applicant: true },
    });
    return this.toDto(post, applications, caller.id);
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
  /// the marketplace sells activity hosting, not dates.
  async apply(
    caller: User,
    postId: string,
    proposal: string,
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
      data: { postId, applicantId: caller.id, proposal },
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
      const created = await tx.order.create({
        data: {
          postId,
          payerId: payer.id,
          earnerId: earner.id,
          status: OrderStatus.awaitingPayment,
          feeMinor: split.feeMinor,
          commissionMinor: split.commissionMinor,
          netMinor: split.netMinor,
        },
        include: { payer: true, earner: true, post: true },
      });
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
    return toOrderDto(order);
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
    callerId = '',
  ): PostDto {
    const selected = applications.find(
      (a) => a.status === ApplicationStatus.selected,
    );
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
      applicantCount: applications.filter(
        (a) => a.status !== ApplicationStatus.released,
      ).length,
      status: post.status,
      feeMinor: post.feeMinor,
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
      proposal: application.proposal,
      createdAt: application.createdAt,
    };
  }
}
