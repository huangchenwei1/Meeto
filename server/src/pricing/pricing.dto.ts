import { Type } from 'class-transformer';
import { IsInt, IsObject, Max, Min } from 'class-validator';

export class PricingConfigDto {
  /// Commission in basis points (1000 = 10%).
  @IsInt()
  @Min(0)
  @Max(10000)
  @Type(() => Number)
  platformFeeRateBp!: number;

  @IsInt()
  @Min(0)
  @Type(() => Number)
  defaultFeeMinor!: number;

  /// Scene tag -> selectable activity budget tiers (minor units, ascending).
  /// The poster picks one; the middle tier is the default.
  @IsObject()
  sceneBudgetTiers!: Record<string, number[]>;
}
