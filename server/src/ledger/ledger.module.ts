import { Module } from '@nestjs/common';
import { LedgerService } from './ledger.service.js';
import { WalletController } from './wallet.controller.js';

@Module({
  controllers: [WalletController],
  providers: [LedgerService],
  exports: [LedgerService],
})
export class LedgerModule {}
