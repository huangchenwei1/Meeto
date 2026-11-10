import {
  ArrayMaxSize,
  ArrayNotEmpty,
  IsArray,
  IsIn,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreatePostDto {
  /// The platform activity template this post launches from — the only
  /// publish path. Scene, cover, district and meeting point all resolve
  /// server-side from the template.
  @IsString()
  @IsNotEmpty()
  templateId!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsOptional()
  @IsString()
  description?: string;

  /// The concrete meeting time. Duration is the platform standard, so
  /// this fully schedules the activity.
  @IsISO8601()
  scheduledAt!: string;

  /// Activity budget tier pick (minor units). Must be one of the platform
  /// tiers for the scene; omitted -> the middle tier.
  @IsOptional()
  @IsInt()
  @Min(0)
  budgetMinor?: number;

  /// Who covers on-site expenses: TREAT (the publisher treats, default)
  /// or AA (everyone pays their own).
  @IsOptional()
  @IsIn(['TREAT', 'AA'])
  expensePolicy?: 'TREAT' | 'AA';
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

