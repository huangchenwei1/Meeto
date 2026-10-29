import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module.js';
import { HostsController, InvitationsController } from './hosts.controller.js';
import { HostsService } from './hosts.service.js';

@Module({
  imports: [PricingModule],
  controllers: [HostsController, InvitationsController],
  providers: [HostsService],
})
export class HostsModule {}
