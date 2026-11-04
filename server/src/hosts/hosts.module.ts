import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module.js';
import {
  HostsController,
  ProposalsController,
} from './hosts.controller.js';
import { HostsService } from './hosts.service.js';

@Module({
  imports: [PricingModule],
  controllers: [HostsController, ProposalsController],
  providers: [HostsService],
})
export class HostsModule {}
