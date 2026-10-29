import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module.js';
import { PostsController } from './posts.controller.js';
import { PostsService } from './posts.service.js';

@Module({
  imports: [PricingModule],
  controllers: [PostsController],
  providers: [PostsService],
})
export class PostsModule {}
