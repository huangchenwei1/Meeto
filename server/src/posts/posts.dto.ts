import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreatePostDto {
  @IsString()
  @IsNotEmpty()
  sceneTag!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsString()
  detail?: string;

  @IsOptional()
  @IsString()
  imageUrl?: string;

  /// Fuzzy availability window identifier, e.g. TONIGHT or WEEKEND.
  @IsOptional()
  @IsString()
  @MaxLength(40)
  timeSlot?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  area?: string;

  /// Activity budget tier pick (minor units). Must be one of the platform
  /// tiers for the scene; omitted -> the middle tier.
  @IsOptional()
  @IsInt()
  @Min(0)
  budgetMinor?: number;
}

export class CreateMomentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(600)
  text!: string;

  /// Photos carry the recap — the community wall renders image-led
  /// cards — so at least one is required.
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  images!: string[];

  /// Venue name (e.g. a cafe or cinema): the recommendation itself, so it
  /// is required — a recap without the place has no reuse value.
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  venue!: string;
}

export class SelectionDto {
  @IsString()
  @IsNotEmpty()
  applicationId!: string;
}

export class ApplyDto {
  /// The host's one-line plan pitch; required so selection is always a
  /// choice between concrete plans.
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  proposal!: string;

  /// The plan card rides on the sign-up: concrete venue...
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  place!: string;

  /// ...and concrete time. Selecting the candidate approves this plan, so
  /// the paid order starts with chat open and the plan already locked.
  @IsISO8601()
  scheduledAt!: string;

  /// How long the activity runs, in minutes.
  @IsInt()
  @Min(30)
  @Max(720)
  durationMinutes!: number;
}
