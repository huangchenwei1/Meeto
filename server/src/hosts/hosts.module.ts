import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module.js';
import {
  HostsController,
  InvitationsController,
  ProposalsController,
} from './hosts.controller.js';
import { HostsService } from './hosts.service.js';

@Module({
  imports: [PricingModule],
  controllers: [HostsController, InvitationsController, ProposalsController],
  providers: [HostsService],
})
export class HostsModule {}
