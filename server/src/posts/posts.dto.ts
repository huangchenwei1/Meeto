import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
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
}

export class CreateMomentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(600)
  text!: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(6)
  @IsString({ each: true })
  images?: string[];

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
}
