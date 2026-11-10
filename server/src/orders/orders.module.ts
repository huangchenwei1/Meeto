import { Module } from '@nestjs/common';
import { LedgerModule } from '../ledger/ledger.module.js';
import {
  MockPaymentProvider,
  PAYMENT_PROVIDER,
} from '../payments/payment.provider.js';
import { PricingModule } from '../pricing/pricing.module.js';
import { OrdersController } from './orders.controller.js';
import { OrdersService } from './orders.service.js';

@Module({
  imports: [LedgerModule, PricingModule],
  controllers: [OrdersController],
  providers: [
    OrdersService,
    // PRODUCTION: swap MockPaymentProvider for the real channel adapter.
    { provide: PAYMENT_PROVIDER, useClass: MockPaymentProvider },
  ],
  exports: [OrdersService],
})
export class OrdersModule {}
