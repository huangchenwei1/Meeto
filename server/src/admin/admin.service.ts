import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ApplicationStatus,
  PostStatus,
  ReportStatus,
  Role,
  UserStatus,
} from '../common/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

/** The ops view of an account: enough to identify and act, no more. */
export interface AdminUserDto {
  id: string;
  name: string;
  phone: string;
  role: string;
  status: string;
  isVerified: boolean;
  createdAt: Date;
}

/** An in-room safety report with just enough context to act on it. */
export interface AdminReportDto {
  id: string;
  status: string;
  reason: string;
  createdAt: Date;
  orderId: string;
  orderStatus: string;
  reporter: { id: string; name: string };
  reported: { id: string; name: string };
}

/// Ops-only account and safety actions. Everything here sits behind
/// AdminGuard; the public product never calls into this module.
@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  /// Finds accounts by phone or display name for the ops console.
  async searchUsers(query: string): Promise<AdminUserDto[]> {
    const q = query.trim();
    if (q.length === 0) return [];
    const users = await this.prisma.user.findMany({
      where: {
        OR: [{ phone: { contains: q } }, { name: { contains: q } }],
      },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return users.map((u) => AdminService.toAdminUser(u));
  }

  /// Bans an account and takes its open inventory off the market in the
  /// same transaction. Money is deliberately untouched: live orders are
  /// resolved one by one (force-refund) because the counterparty is
  /// innocent.
  async ban(userId: string): Promise<AdminUserDto> {
    const user = await this.findUserOrThrow(userId);
    if (user.role === Role.admin) {
      throw new ForbiddenException('Cannot ban an admin account');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      await tx.post.updateMany({
        where: { authorId: userId, status: PostStatus.open },
        data: { status: PostStatus.cancelled },
      });
      await tx.proposal.updateMany({
        where: { hostId: userId, status: PostStatus.open },
        data: { status: PostStatus.cancelled },
      });
      // Pending sign-ups vanish from candidate pools.
      await tx.application.updateMany({
        where: { applicantId: userId, status: ApplicationStatus.applied },
        data: { status: ApplicationStatus.released },
      });
      return tx.user.update({
        where: { id: userId },
        data: { status: UserStatus.banned },
      });
    });
    return AdminService.toAdminUser(updated);
  }

  /// Lifts a ban. Taken-down inventory stays down: the user republishes
  /// what still matters.
  async unban(userId: string): Promise<AdminUserDto> {
    await this.findUserOrThrow(userId);
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status: UserStatus.active },
    });
    return AdminService.toAdminUser(updated);
  }

  /// All safety reports, open ones first. Each carries both parties so
  /// ops can jump straight to a ban or a refund.
  async listReports(): Promise<AdminReportDto[]> {
    const reports = await this.prisma.report.findMany({
      include: {
        reporter: true,
        order: { include: { payer: true, earner: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    const open = reports.filter((r) => r.status === ReportStatus.open);
    const rest = reports.filter((r) => r.status !== ReportStatus.open);
    return [...open, ...rest].map((r) => {
      const reported =
        r.reporterId === r.order.payerId ? r.order.earner : r.order.payer;
      return {
        id: r.id,
        status: r.status,
        reason: r.reason,
        createdAt: r.createdAt,
        orderId: r.orderId,
        orderStatus: r.order.status,
        reporter: { id: r.reporter.id, name: r.reporter.name },
        reported: { id: reported.id, name: reported.name },
      };
    });
  }

  /// Closes a report; the order's settlement clock resumes on the next
  /// read (see OrdersService.maybeSettle).
  async resolveReport(reportId: string): Promise<{ id: string }> {
    const report = await this.prisma.report.findUnique({
      where: { id: reportId },
    });
    if (!report) {
      throw new NotFoundException('Report not found');
    }
    await this.prisma.report.update({
      where: { id: reportId },
      data: { status: ReportStatus.resolved },
    });
    return { id: reportId };
  }

  private async findUserOrThrow(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return user;
  }

  private static toAdminUser(user: {
    id: string;
    name: string;
    phone: string;
    role: string;
    status: string;
    verificationStatus: string;
    createdAt: Date;
  }): AdminUserDto {
    return {
      id: user.id,
      name: user.name,
      phone: user.phone,
      role: user.role,
      status: user.status,
      isVerified: user.verificationStatus === 'VERIFIED',
      createdAt: user.createdAt,
    };
  }
}
