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

  @IsOptional()
  @IsString()
  @MaxLength(40)
  timeSlot?: string;

  /// Platform budget tier picked by the host (minor units); the middle
  /// tier of the scene when omitted.
  @IsOptional()
  @IsInt()
  @Min(0)
  budgetMinor?: number;
}

/// Inviting on a proposal carries only the note: the scene and the price
/// are locked to the pitch server-side.
class InviteDto {
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

  /// Hall feed: hosts' open activity pitches, newest first.
  @Get()
  feed(@CurrentUser() user: User) {
    return this.hosts.proposalFeed(user);
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
      dto.timeSlot ?? '',
      dto.budgetMinor,
    );
  }

  @Get(':id')
  getOne(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.getProposal(user, id);
  }

  /// A user queues an invitation on the pitch (mirror of a post sign-up).
  @Post(':id/invitations')
  invite(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: InviteDto,
  ) {
    return this.hosts.invite(user, id, dto.note ?? '');
  }

  /// The pending invite pool, visible to the proposal's host only.
  @Get(':id/invitations')
  listInvites(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.listInvites(user, id);
  }

  /// The host picks one inviter: creates the order awaiting payment.
  @Post(':id/invitations/:invitationId/select')
  select(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Param('invitationId') invitationId: string,
  ) {
    return this.hosts.select(user, id, invitationId);
  }
}
