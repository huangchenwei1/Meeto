import {
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import type { User } from '@prisma/client';
import type { Gender, Role } from '../common/enums.js';
import { toPublicUser } from '../common/user.mapper.js';
import type { PublicUser } from '../common/user.mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { SMS_PROVIDER } from './sms.provider.js';
import type { SmsProvider } from './sms.provider.js';

const OTP_TTL_MS = 5 * 60 * 1000;
const ACCESS_TOKEN_TTL = '7d'; // demo convenience; production shortens this
const REFRESH_TOKEN_TTL = '30d';
const REGISTRATION_TOKEN_TTL = '10m';

/// Fixed OTP outside production so demo flows and tests are deterministic.
const DEV_OTP_CODE = '123456';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

export interface VerifyResult {
  status: 'LOGGED_IN' | 'NEEDS_PROFILE';
  accessToken?: string;
  refreshToken?: string;
  user?: PublicUser;
  registrationToken?: string;
}

interface OtpRecord {
  code: string;
  expiresAt: number;
}

const isProduction = () => process.env.NODE_ENV === 'production';

@Injectable()
export class AuthService {
  /// In-memory OTP store. Production moves this to Redis (multi-instance,
  /// rate limiting, attempt counters); the flow stays identical.
  private readonly otpByPhone = new Map<string, OtpRecord>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    @Inject(SMS_PROVIDER) private readonly sms: SmsProvider,
  ) {}

  async requestOtp(phone: string): Promise<{ sent: boolean; devCode?: string }> {
    const code = isProduction()
      ? Math.floor(100000 + Math.random() * 900000).toString()
      : DEV_OTP_CODE;
    this.otpByPhone.set(phone, { code, expiresAt: Date.now() + OTP_TTL_MS });
    await this.sms.sendOtp(phone, code);
    return isProduction() ? { sent: true } : { sent: true, devCode: code };
  }

  async verifyOtp(phone: string, code: string): Promise<VerifyResult> {
    const record = this.otpByPhone.get(phone);
    if (!record || record.expiresAt < Date.now() || record.code !== code) {
      throw new UnauthorizedException('Invalid or expired code');
    }
    this.otpByPhone.delete(phone); // single-use

    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (user) {
      return {
        status: 'LOGGED_IN',
        ...(await this.issueTokens(user.id)),
        user: toPublicUser(user),
      };
    }
    const registrationToken = await this.jwt.signAsync(
      { sub: phone, typ: 'register' },
      { expiresIn: REGISTRATION_TOKEN_TTL },
    );
    return { status: 'NEEDS_PROFILE', registrationToken };
  }

  /// The account role (USER posts and pays, HOST hosts and earns) is picked
  /// at registration and fixed for the account's lifetime.
  async register(
    registrationToken: string,
    name: string,
    gender: Gender,
    role: Role,
  ): Promise<TokenPair & { user: PublicUser }> {
    const phone = await this.verifyTokenOfType(registrationToken, 'register');
    const existing = await this.prisma.user.findUnique({ where: { phone } });
    if (existing) {
      throw new UnauthorizedException('Phone already registered');
    }
    const user = await this.prisma.user.create({
      data: {
        phone,
        name: name.trim(),
        gender,
        role,
        meta: `${gender === 'FEMALE' ? 'Female' : 'Male'}`,
      },
    });
    return { ...(await this.issueTokens(user.id)), user: toPublicUser(user) };
  }

  async refresh(refreshToken: string): Promise<TokenPair> {
    const userId = await this.verifyTokenOfType(refreshToken, 'refresh');
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Unknown user');
    }
    return this.issueTokens(user.id);
  }

  /// Resolves the user for a bearer access token; used by the auth guard.
  async resolveAccessToken(token: string): Promise<User> {
    const userId = await this.verifyTokenOfType(token, 'access');
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('Unknown user');
    }
    return user;
  }

  private async issueTokens(userId: string): Promise<TokenPair> {
    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(
        { sub: userId, typ: 'access' },
        { expiresIn: ACCESS_TOKEN_TTL },
      ),
      this.jwt.signAsync(
        { sub: userId, typ: 'refresh' },
        { expiresIn: REFRESH_TOKEN_TTL },
      ),
    ]);
    return { accessToken, refreshToken };
  }

  private async verifyTokenOfType(token: string, typ: string): Promise<string> {
    try {
      const payload = await this.jwt.verifyAsync<{ sub: string; typ: string }>(
        token,
      );
      if (payload.typ !== typ) {
        throw new Error('wrong token type');
      }
      return payload.sub;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
