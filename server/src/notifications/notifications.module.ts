import {
  Controller,
  Get,
  Global,
  Injectable,
  Module,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { Notification, Prisma, User } from '@prisma/client';
import { AuthGuard, CurrentUser } from '../common/auth.guard.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface NotificationDto {
  id: string;
  type: string;
  actorName: string;
  actorAvatarUrl: string;
  postId: string;
  orderId: string;
  isRead: boolean;
  createdAt: Date;
}

export interface NotificationInput {
  userId: string;
  type: string;
  actorName?: string;
  actorAvatarUrl?: string;
  postId?: string;
  orderId?: string;
}

/// Writes in-app notifications. Fired inside the same transaction as the
/// triggering domain event so a notification never exists for an event
/// that rolled back. A future push channel (APNs/FCM) hooks in here.
@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  async notify(
    tx: Prisma.TransactionClient | PrismaService,
    input: NotificationInput,
  ): Promise<void> {
    await tx.notification.create({
      data: {
        userId: input.userId,
        type: input.type,
        actorName: input.actorName ?? '',
        actorAvatarUrl: input.actorAvatarUrl ?? '',
        postId: input.postId ?? '',
        orderId: input.orderId ?? '',
      },
    });
  }
}

@Controller('notifications')
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list(@CurrentUser() user: User): Promise<NotificationDto[]> {
    const rows = await this.prisma.notification.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    return rows.map(toNotificationDto);
  }

  @Get('unread-count')
  async unreadCount(@CurrentUser() user: User): Promise<{ count: number }> {
    const count = await this.prisma.notification.count({
      where: { userId: user.id, readAt: null },
    });
    return { count };
  }

  @Post('read')
  async markAllRead(@CurrentUser() user: User): Promise<{ count: number }> {
    const res = await this.prisma.notification.updateMany({
      where: { userId: user.id, readAt: null },
      data: { readAt: new Date() },
    });
    return { count: res.count };
  }
}

function toNotificationDto(row: Notification): NotificationDto {
  return {
    id: row.id,
    type: row.type,
    actorName: row.actorName,
    actorAvatarUrl: row.actorAvatarUrl,
    postId: row.postId,
    orderId: row.orderId,
    isRead: row.readAt !== null,
    createdAt: row.createdAt,
  };
}

@Global()
@Module({
  controllers: [NotificationsController],
  providers: [NotificationsService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
