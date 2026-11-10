import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AdminGuard, AuthGuard } from '../common/auth.guard.js';
import type { OrderDto } from '../orders/order.mapper.js';
import { OrdersService } from '../orders/orders.service.js';
import { PricingConfigDto } from '../pricing/pricing.dto.js';
import { PricingService } from '../pricing/pricing.service.js';
import type { AdminReportDto, AdminUserDto } from './admin.service.js';
import { AdminService } from './admin.service.js';

/// Platform operations: runtime repricing, order oversight, and the
/// safety console (ban / takedown / force refund / reports).
@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
  constructor(
    private readonly pricingService: PricingService,
    private readonly ordersService: OrdersService,
    private readonly adminService: AdminService,
  ) {}

  @Put('pricing')
  updatePricing(@Body() input: PricingConfigDto): Promise<PricingConfigDto> {
    return this.pricingService.updateConfig(input);
  }

  @Get('orders')
  listOrders(@Query('status') status?: string): Promise<OrderDto[]> {
    return this.ordersService.listAll(status);
  }

  @Get('users')
  searchUsers(@Query('q') q?: string): Promise<AdminUserDto[]> {
    return this.adminService.searchUsers(q ?? '');
  }

  @Post('users/:id/ban')
  ban(@Param('id') id: string): Promise<AdminUserDto> {
    return this.adminService.ban(id);
  }

  @Post('users/:id/unban')
  unban(@Param('id') id: string): Promise<AdminUserDto> {
    return this.adminService.unban(id);
  }

  @Post('orders/:id/refund')
  refund(@Param('id') id: string): Promise<OrderDto> {
    return this.ordersService.adminRefund(id);
  }

  @Get('reports')
  listReports(): Promise<AdminReportDto[]> {
    return this.adminService.listReports();
  }

  @Post('reports/:id/resolve')
  resolveReport(@Param('id') id: string): Promise<{ id: string }> {
    return this.adminService.resolveReport(id);
  }
}
