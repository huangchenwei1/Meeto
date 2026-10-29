import { Module } from '@nestjs/common';
import { OrdersModule } from '../orders/orders.module.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { AdminController } from './admin.controller.js';

@Module({
  imports: [PricingModule, OrdersModule],
  controllers: [AdminController],
})
export class AdminModule {}
