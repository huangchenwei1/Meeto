import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import { CurrentUser, AuthGuard } from '../common/auth.guard.js';
import type { OrderDto } from '../orders/order.mapper.js';
import {
  ApplyDto,
  CreateMomentDto,
  CreatePostDto,
  SelectionDto,
} from './posts.dto.js';
import { PostsService } from './posts.service.js';
import type { ApplicationDto, PostDto } from './posts.service.js';
import {
  ACTIVITY_TEMPLATES,
  type ActivityTemplate,
} from './activity-templates.js';

/// Curated activity templates for the "hot activities" shelf. Static
/// operations content; both roles read the same list.
@Controller('templates')
@UseGuards(AuthGuard)
export class TemplatesController {
  @Get()
  list(): ActivityTemplate[] {
    return ACTIVITY_TEMPLATES;
  }
}

@Controller('posts')
@UseGuards(AuthGuard)
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get()
  feed(
    @CurrentUser() user: User,
    @Query('scene') scene?: string,
    @Query('authorId') authorId?: string,
    @Query('view') view?: string,
  ): Promise<PostDto[]> {
    return this.postsService.feed(user, scene, authorId, view);
  }

  @Post()
  create(
    @CurrentUser() user: User,
    @Body() input: CreatePostDto,
  ): Promise<PostDto> {
    return this.postsService.create(user, input);
  }

  @Post('moments')
  createMoment(
    @CurrentUser() user: User,
    @Body() input: CreateMomentDto,
  ): Promise<PostDto> {
    return this.postsService.createMoment(
      user,
      input.text,
      input.images ?? [],
      input.venue,
    );
  }

  @Delete(':id')
  remove(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<PostDto> {
    return this.postsService.remove(user, id);
  }

  @Get(':id')
  getOne(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<PostDto> {
    return this.postsService.getOne(user, id);
  }

  @Get(':id/applications')
  listApplications(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<ApplicationDto[]> {
    return this.postsService.listApplications(user, id);
  }

  @Post(':id/applications')
  apply(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() input: ApplyDto,
  ): Promise<ApplicationDto> {
    return this.postsService.apply(user, id, input);
  }

  @Post(':id/selection')
  select(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() input: SelectionDto,
  ): Promise<OrderDto> {
    return this.postsService.select(user, id, input.applicationId);
  }
}
