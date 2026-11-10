import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import type { Request } from 'express';
import { AuthService } from '../auth/auth.service.js';
import { Role, UserStatus } from './enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface AuthedRequest extends Request {
  user: User;
}

/// Demo-header auth (`X-User-Id`) is allowed outside production so demo
/// director flows can impersonate seeded counterparties. Production builds
/// accept bearer tokens only.
const demoHeaderAllowed = () =>
  process.env.NODE_ENV !== 'production' &&
  process.env.ALLOW_DEMO_AUTH !== 'false';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthedRequest>();

    const header = request.header('authorization');
    if (header?.startsWith('Bearer ')) {
      request.user = await this.auth.resolveAccessToken(header.slice(7));
      AuthGuard.assertNotBanned(request.user);
      return true;
    }

    const demoUserId = request.header('x-user-id');
    if (demoHeaderAllowed() && demoUserId) {
      const user = await this.prisma.user.findUnique({
        where: { id: demoUserId },
      });
      if (!user) {
        throw new UnauthorizedException('Unknown user');
      }
      AuthGuard.assertNotBanned(user);
      request.user = user;
      return true;
    }

    throw new UnauthorizedException('Missing credentials');
  }

  /// A ban needs no token expiry: every authenticated request re-checks
  /// the account standing, so the ban lands on the very next tap.
  private static assertNotBanned(user: User): void {
    if (user.status === UserStatus.banned) {
      throw new ForbiddenException('ACCOUNT_BANNED');
    }
  }
}

/// Requires AuthGuard to have populated `request.user` first.
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    if (request.user.role !== Role.admin) {
      throw new ForbiddenException('Admin access required');
    }
    return true;
  }
}

export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): User => {
    const request = context.switchToHttp().getRequest<AuthedRequest>();
    return request.user;
  },
);
