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
  IsISO8601,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { CurrentUser, AuthGuard } from '../common/auth.guard.js';
import type { MessageDto, OrderDto } from './order.mapper.js';
import { OrdersService } from './orders.service.js';

class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  text!: string;
}

class StartDto {
  /// The payer's 4-digit meet code, asked for in person.
  @IsString()
  @Length(4, 4)
  code!: string;
}

@Controller('orders')
@UseGuards(AuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  /// Default: conversations (escrowed orders) for the Messages tab.
  /// view=all: the full order history for the My Orders page.
  @Get()
  listMine(
    @CurrentUser() user: User,
    @Query('view') view?: string,
  ): Promise<OrderDto[]> {
    return this.ordersService.listMine(user, view);
  }

  @Get(':id')
  getOne(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<OrderDto> {
    return this.ordersService.getOne(user, id);
  }

  @Post(':id/payment')
  pay(@CurrentUser() user: User, @Param('id') id: string): Promise<OrderDto> {
    return this.ordersService.pay(user, id);
  }

  @Post(':id/start')
  start(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: StartDto,
  ): Promise<OrderDto> {
    return this.ordersService.start(user, id, dto.code);
  }

  @Post(':id/cancel')
  cancel(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<OrderDto> {
    return this.ordersService.cancel(user, id);
  }

  @Post(':id/messages')
  sendMessage(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ): Promise<MessageDto> {
    return this.ordersService.sendMessage(user, id, dto.text);
  }

  @Get(':id/messages')
  listMessages(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Query('afterId') afterId?: string,
  ): Promise<MessageDto[]> {
    return this.ordersService.listMessages(user, id, afterId);
  }
}
