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

  /// Scene tag -> match fee in minor units.
  @IsObject()
  sceneFees!: Record<string, number>;
}
