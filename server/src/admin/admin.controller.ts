import {
  Body,
  Controller,
  Get,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminGuard, AuthGuard } from '../common/auth.guard.js';
import type { OrderDto } from '../orders/order.mapper.js';
import { OrdersService } from '../orders/orders.service.js';
import { PricingConfigDto } from '../pricing/pricing.dto.js';
import { PricingService } from '../pricing/pricing.service.js';

/// Platform operations: runtime repricing and order oversight.
@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly ordersService: OrdersService,
  ) {}

  @Put('pricing')
  updatePricing(@Body() input: PricingConfigDto): Promise<PricingConfigDto> {
    return this.pricingService.updateConfig(input);
  }

  @Get('orders')
  listOrders(@Query('status') status?: string): Promise<OrderDto[]> {
    return this.ordersService.listAll(status);
  }
}
