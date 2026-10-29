import { Controller, Get } from '@nestjs/common';
import { PricingConfigDto } from './pricing.dto.js';
import { PricingService } from './pricing.service.js';

/// Public: clients load pricing at startup (no auth required).
@Controller('config')
export class PricingController {
  constructor(private readonly pricingService: PricingService) {}

  @Get('pricing')
  getPricing(): Promise<PricingConfigDto> {
    return this.pricingService.getConfig();
  }
}
