import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service.js';
import { PricingConfigDto } from './pricing.dto.js';

export interface FeeSplit {
  feeMinor: number;
  commissionMinor: number;
  netMinor: number;
}

/// Platform pricing: single-row config, adjustable at runtime via the admin
/// API. Posts snapshot the fee at publish time and orders snapshot the full
/// split at creation time, so repricing never mutates in-flight business.
@Injectable()
export class PricingService {
  constructor(private readonly prisma: PrismaService) {}

  private static readonly configRowId = 1;

  async getConfig(): Promise<PricingConfigDto> {
    const row = await this.prisma.pricingConfig.findUniqueOrThrow({
      where: { id: PricingService.configRowId },
    });
    return {
      platformFeeRateBp: row.platformFeeRateBp,
      defaultFeeMinor: row.defaultFeeMinor,
      sceneBudgetTiers: JSON.parse(row.sceneBudgetTiersJson) as Record<
        string,
        number[]
      >,
    };
  }

  async updateConfig(input: PricingConfigDto): Promise<PricingConfigDto> {
    await this.prisma.pricingConfig.update({
      where: { id: PricingService.configRowId },
      data: {
        platformFeeRateBp: input.platformFeeRateBp,
        defaultFeeMinor: input.defaultFeeMinor,
        sceneBudgetTiersJson: JSON.stringify(input.sceneBudgetTiers),
      },
    });
    return input;
  }

  /// Resolves the activity budget for a post or invitation. The platform
  /// prices in tiers: a missing pick falls back to the middle tier; a pick
  /// outside the scene's tier list is rejected (posters cannot free-price).
  async resolveBudget(
    sceneTag: string,
    budgetMinor?: number,
  ): Promise<number> {
    const config = await this.getConfig();
    const tiers = config.sceneBudgetTiers[sceneTag] ?? [
      config.defaultFeeMinor,
    ];
    if (budgetMinor === undefined) {
      return tiers[Math.floor((tiers.length - 1) / 2)];
    }
    if (!tiers.includes(budgetMinor)) {
      throw new BadRequestException('INVALID_BUDGET');
    }
    return budgetMinor;
  }

  /// ACCOUNTING INVARIANT: commission is rounded, net is the exact
  /// remainder, so feeMinor === commissionMinor + netMinor always holds.
  /// (The Flutter demo derives net = round(fee * (1 - rate)) for display
  /// only; the server split is the source of truth from Phase 3 on.)
  async splitFee(feeMinor: number): Promise<FeeSplit> {
    const config = await this.getConfig();
    const commissionMinor = Math.round(
      (feeMinor * config.platformFeeRateBp) / 10000,
    );
    return {
      feeMinor,
      commissionMinor,
      netMinor: feeMinor - commissionMinor,
    };
  }
}
