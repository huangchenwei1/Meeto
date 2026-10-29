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
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuthGuard, CurrentUser } from '../common/auth.guard.js';
import { HostsService } from './hosts.service.js';

class InviteDto {
  @IsString()
  @IsNotEmpty()
  hostId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  sceneTag!: string;

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

@Controller('invitations')
@UseGuards(AuthGuard)
export class InvitationsController {
  constructor(private readonly hosts: HostsService) {}

  @Post()
  invite(@CurrentUser() user: User, @Body() dto: InviteDto) {
    return this.hosts.invite(user, dto.hostId, dto.sceneTag, dto.note ?? '');
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
