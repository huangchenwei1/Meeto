import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  UseGuards,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import {
  IsArray,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';
import { CurrentUser, AuthGuard } from '../common/auth.guard.js';
import { OrderStatus, PostStatus } from '../common/enums.js';
import { ageFrom, toPublicUser } from '../common/user.mapper.js';
import type { PublicUser } from '../common/user.mapper.js';
import { PrismaService } from '../prisma/prisma.service.js';

class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MaxLength(40)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(600)
  bio?: string;

  @IsOptional()
  @IsISO8601()
  birthDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  country?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  job?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  education?: string;

  @IsOptional()
  @IsInt()
  @Min(120)
  @Max(230)
  @Type(() => Number)
  heightCm?: number;

  @IsOptional()
  @IsInt()
  @Min(30)
  @Max(200)
  @Type(() => Number)
  weightKg?: number;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  @MaxLength(30, { each: true })
  tags?: string[];

  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  photos?: string[];
}

/// PublicUser plus cross-table aggregates for the profile page.
type ProfileView = PublicUser & { activitiesCompleted: number; activityPosts: number };

/// Own profile only: includes the raw birth date so the edit form can
/// prefill it. Other users only ever see the derived age.
type OwnProfileView = ProfileView & { birthDate: Date | null };

@Controller('users')
@UseGuards(AuthGuard)
export class UsersController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('me')
  async getMe(@CurrentUser() user: User): Promise<OwnProfileView> {
    return { ...(await this.toProfileView(user)), birthDate: user.birthDate };
  }

  /// Partial profile update for the signed-in user. Gender is intentionally
  /// not editable: it drives the payment rules.
  @Patch('me')
  async updateMe(
    @CurrentUser() user: User,
    @Body() dto: UpdateProfileDto,
  ): Promise<OwnProfileView> {
    // The display name can be edited but never blanked.
    if (dto.name !== undefined && dto.name.trim().length === 0) {
      throw new BadRequestException('NAME_REQUIRED');
    }
    let birthDate: Date | undefined;
    if (dto.birthDate !== undefined) {
      // The birth date backs the 18+ gate: it can be set once during
      // registration and is locked afterwards.
      if (user.birthDate !== null) {
        throw new BadRequestException('BIRTH_DATE_LOCKED');
      }
      birthDate = new Date(dto.birthDate);
      const age = ageFrom(birthDate);
      if (age === null || age < 18 || age > 99) {
        throw new BadRequestException('MUST_BE_18_PLUS');
      }
    }
    const updated = await this.prisma.user.update({
      where: { id: user.id },
      data: {
        ...(dto.name !== undefined ? { name: dto.name.trim() } : {}),
        ...(dto.bio !== undefined ? { bio: dto.bio } : {}),
        ...(birthDate !== undefined ? { birthDate } : {}),
        ...(dto.country !== undefined ? { country: dto.country } : {}),
        ...(dto.city !== undefined ? { city: dto.city } : {}),
        ...(dto.job !== undefined ? { job: dto.job } : {}),
        ...(dto.education !== undefined ? { education: dto.education } : {}),
        ...(dto.heightCm !== undefined ? { heightCm: dto.heightCm } : {}),
        ...(dto.weightKg !== undefined ? { weightKg: dto.weightKg } : {}),
        ...(dto.tags !== undefined
          ? { tagsJson: JSON.stringify(dto.tags) }
          : {}),
        ...(dto.avatarUrl !== undefined ? { avatarUrl: dto.avatarUrl } : {}),
        ...(dto.photos !== undefined
          ? { photosJson: JSON.stringify(dto.photos) }
          : {}),
      },
    });
    return {
      ...(await this.toProfileView(updated)),
      birthDate: updated.birthDate,
    };
  }

  @Get(':id')
  async getById(@Param('id') id: string): Promise<ProfileView> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.toProfileView(user);
  }

  private async toProfileView(user: User): Promise<ProfileView> {
    const [activitiesCompleted, activityPosts] = await Promise.all([
      this.prisma.order.count({
        where: {
          status: OrderStatus.completed,
          OR: [{ payerId: user.id }, { earnerId: user.id }],
        },
      }),
      // Published posts; cancelled/deleted ones do not count.
      this.prisma.post.count({
        where: {
          authorId: user.id,
          NOT: { status: PostStatus.cancelled },
        },
      }),
    ]);
    return { ...toPublicUser(user), activitiesCompleted, activityPosts };
  }
}
