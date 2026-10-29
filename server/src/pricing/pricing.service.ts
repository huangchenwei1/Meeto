import { Injectable } from '@nestjs/common';
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
      sceneFees: JSON.parse(row.sceneFeesJson) as Record<string, number>,
    };
  }

  async updateConfig(input: PricingConfigDto): Promise<PricingConfigDto> {
    await this.prisma.pricingConfig.update({
      where: { id: PricingService.configRowId },
      data: {
        platformFeeRateBp: input.platformFeeRateBp,
        defaultFeeMinor: input.defaultFeeMinor,
        sceneFeesJson: JSON.stringify(input.sceneFees),
      },
    });
    return input;
  }

  async feeForScene(sceneTag: string): Promise<number> {
    const config = await this.getConfig();
    return config.sceneFees[sceneTag] ?? config.defaultFeeMinor;
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
