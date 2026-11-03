import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { User } from '@prisma/client';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuthGuard, CurrentUser } from '../common/auth.guard.js';
import { HostsService } from './hosts.service.js';

class CreateProposalDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  sceneTag!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  imageUrl?: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  area?: string;
}

class InviteDto {
  @IsString()
  @IsNotEmpty()
  hostId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  sceneTag!: string;

  /// Activity budget tier pick (minor units). Must be one of the platform
  /// tiers for the scene; omitted -> the middle tier.
  @IsOptional()
  @IsInt()
  @Min(0)
  budgetMinor?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

@Controller('hosts')
@UseGuards(AuthGuard)
export class HostsController {
  constructor(private readonly hosts: HostsService) {}

  @Get()
  directory(@Query('gender') gender?: string) {
    return this.hosts.directory(gender);
  }

  @Get(':id')
  getHost(@Param('id') id: string) {
    return this.hosts.getHost(id);
  }
}

@Controller('proposals')
@UseGuards(AuthGuard)
export class ProposalsController {
  constructor(private readonly hosts: HostsService) {}

  /// User home feed: hosts' activity pitches, newest first.
  @Get()
  feed() {
    return this.hosts.proposalFeed();
  }

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateProposalDto) {
    return this.hosts.createProposal(
      user,
      dto.title,
      dto.description ?? '',
      dto.sceneTag,
      dto.imageUrl ?? '',
      dto.area ?? '',
    );
  }
}

@Controller('invitations')
@UseGuards(AuthGuard)
export class InvitationsController {
  constructor(private readonly hosts: HostsService) {}

  @Post()
  invite(@CurrentUser() user: User, @Body() dto: InviteDto) {
    return this.hosts.invite(
      user,
      dto.hostId,
      dto.sceneTag,
      dto.note ?? '',
      dto.budgetMinor,
    );
  }

  @Get()
  listMine(@CurrentUser() user: User) {
    return this.hosts.listMine(user);
  }

  @Post(':id/accept')
  accept(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.accept(user, id);
  }

  @Post(':id/decline')
  decline(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.decline(user, id);
  }
}
