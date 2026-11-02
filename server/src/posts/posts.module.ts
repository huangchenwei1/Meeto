import { Module } from '@nestjs/common';
import { PricingModule } from '../pricing/pricing.module.js';
import { PostsController, TemplatesController } from './posts.controller.js';
import { PostsService } from './posts.service.js';

@Module({
  imports: [PricingModule],
  controllers: [PostsController, TemplatesController],
  providers: [PostsService],
})
export class PostsModule {}
