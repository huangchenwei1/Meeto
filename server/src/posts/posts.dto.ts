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
  timeText?: string;

  @IsOptional()
  @IsISO8601()
  scheduledAt?: string;

  @IsOptional()
  @IsString()
  place?: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  @Type(() => Number)
  placeLat?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  @Type(() => Number)
  placeLng?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  distanceKm?: number;

  @IsOptional()
  @IsString()
  imageUrl?: string;
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
