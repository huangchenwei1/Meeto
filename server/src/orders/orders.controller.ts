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
  IsBoolean,
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
import type { ConversationDto } from './orders.service.js';

class SendMessageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2000)
  text!: string;
}

/// A rebooking card the payer sends into an existing conversation: the
/// same deal terms as a proposal invitation (template + concrete time +
/// price tier), carried as a special chat message.
class ActivityRequestDto {
  @IsString()
  @IsNotEmpty()
  templateId!: string;

  @IsISO8601()
  scheduledAt!: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  budgetMinor?: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  note?: string;
}

class RespondRequestDto {
  @IsBoolean()
  accept!: boolean;
}

class StartDto {
  /// The payer's 4-digit meet code, asked for in person.
  @IsString()
  @Length(4, 4)
  code!: string;
}

class ReportDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
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

  /// The contact-style conversation list, one row per partner. Declared
  /// before :id so the literal path wins the route match.
  @Get('conversations')
  listConversations(@CurrentUser() user: User): Promise<ConversationDto[]> {
    return this.ordersService.listConversations(user);
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

  /// In-room safety report: freezes the order's settlement until ops
  /// resolves it (community guidelines promise exactly that).
  @Post(':id/report')
  report(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: ReportDto,
  ): Promise<{ id: string }> {
    return this.ordersService.report(user, id, dto.reason);
  }

  @Post(':id/messages')
  sendMessage(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: SendMessageDto,
  ): Promise<MessageDto> {
    return this.ordersService.sendMessage(user, id, dto.text);
  }

  @Post(':id/messages/request')
  sendActivityRequest(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() dto: ActivityRequestDto,
  ): Promise<MessageDto> {
    return this.ordersService.sendActivityRequest(
      user,
      id,
      dto.templateId,
      dto.scheduledAt,
      dto.budgetMinor,
      dto.note ?? '',
    );
  }

  @Post(':id/messages/:messageId/respond')
  respondActivityRequest(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Param('messageId') messageId: string,
    @Body() dto: RespondRequestDto,
  ): Promise<MessageDto> {
    return this.ordersService.respondActivityRequest(
      user,
      id,
      messageId,
      dto.accept,
    );
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
