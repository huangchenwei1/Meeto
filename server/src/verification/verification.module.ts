import {
  Body,
  ConflictException,
  Controller,
  Module,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { AuthGuard, CurrentUser } from '../common/auth.guard.js';
import { VerificationStatus } from '../common/enums.js';
import { PublicUser, toPublicUser } from '../common/user.mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';

export class SubmitVerificationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(300)
  selfieUrl!: string;
}

@Controller('verification')
@UseGuards(AuthGuard)
export class VerificationController {
  constructor(private readonly prisma: PrismaService) {}

  /// MOCK real-person verification: the liveness-captured selfie is matched
  /// against the profile photo, so an avatar must exist first. The mock
  /// comparison always passes; a real KYC vendor replaces it (status would
  /// go through PENDING while the vendor reviews).
  @Post()
  async submit(
    @CurrentUser() user: User,
    @Body() input: SubmitVerificationDto,
  ): Promise<PublicUser> {
    if (user.avatarUrl === '') {
      throw new ConflictException('AVATAR_REQUIRED');
    }
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        verificationStatus: VerificationStatus.verified,
        verificationSelfieUrl: input.selfieUrl,
      },
    });
    return toPublicUser(updated);
  }
}

@Module({ controllers: [VerificationController] })
export class VerificationModule {}
