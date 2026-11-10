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
  IsIn,
  IsInt,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuthGuard, CurrentUser } from '../common/auth.guard.js';
import { HostsService } from './hosts.service.js';

class CreateProposalDto {
  /// The platform activity template the pitch launches from — the only
  /// publish path; scene, cover, district and meeting point resolve
  /// server-side from it.
  @IsString()
  @IsNotEmpty()
  templateId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title!: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string;

  /// The host's rough availability window. The pitch is a service shelf
  /// listing: inviters pick the concrete time and price tier inside it.
  @IsIn(['ANYTIME', 'NOON', 'EVENING'])
  timeSlot!: string;
}

/// Inviting on a proposal is where the deal gets concrete: the inviter
/// picks the meeting time (inside the pitch's window) and the price tier
/// (from the scene's platform tiers), plus an optional note.
class InviteDto {
  /// The concrete meeting time; validated against working hours and the
  /// pitch's declared availability window.
  @IsISO8601()
  scheduledAt!: string;

  /// Platform budget tier picked by the inviter (minor units); the middle
  /// tier of the scene when omitted.
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

  /// Hall feed: hosts' open activity pitches, newest first.
  @Get()
  feed(@CurrentUser() user: User) {
    return this.hosts.proposalFeed(user);
  }

  @Post()
  create(@CurrentUser() user: User, @Body() dto: CreateProposalDto) {
    return this.hosts.createProposal(
      user,
      dto.templateId,
      dto.title,
      dto.description ?? '',
      dto.timeSlot,
    );
  }

  @Get(':id')
  getOne(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.getProposal(user, id);
  }

  /// A user queues an invitation on the pitch, picking the concrete time
  /// and the price tier (mirror of a post sign-up, plus the deal terms).
  @Post(':id/invitations')
  invite(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: InviteDto,
  ) {
    return this.hosts.invite(
      user,
      id,
      dto.scheduledAt,
      dto.budgetMinor,
      dto.note ?? '',
    );
  }

  /// The pending invite pool, visible to the proposal's host only.
  @Get(':id/invitations')
  listInvites(@CurrentUser() user: User, @Param('id') id: string) {
    return this.hosts.listInvites(user, id);
  }

  /// The host picks one inviter. The plan is the template's meeting point
  /// plus the time (and tier) that inviter picked: the order is born with
  /// the plan confirmed, no extra input needed.
  @Post(':id/invitations/:invitationId/select')
  select(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Param('invitationId') invitationId: string,
  ) {
    return this.hosts.select(user, id, invitationId);
  }
}
