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

class PlanDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  place!: string;

  @IsOptional()
  @IsNumber()
  @Min(-90)
  @Max(90)
  placeLat?: number;

  @IsOptional()
  @IsNumber()
  @Min(-180)
  @Max(180)
  placeLng?: number;

  @IsISO8601()
  scheduledAt!: string;

  // The itinerary: place and time alone are not a plan.
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  note!: string;

  // How long the activity runs, in minutes.
  @IsInt()
  @Min(30)
  @Max(720)
  durationMinutes!: number;
}

@Controller('orders')
@UseGuards(AuthGuard)
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Get()
  listMine(@CurrentUser() user: User): Promise<OrderDto[]> {
    return this.ordersService.listMine(user);
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

  @Post(':id/plan')
  proposePlan(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: PlanDto,
  ): Promise<OrderDto> {
    return this.ordersService.proposePlan(user, id, dto);
  }

  @Post(':id/plan/confirm')
  confirmPlan(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<OrderDto> {
    return this.ordersService.confirmPlan(user, id);
  }

  @Post(':id/complete')
  complete(
    @CurrentUser() user: User,
    @Param('id') id: string,
  ): Promise<OrderDto> {
    return this.ordersService.complete(user, id);
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
