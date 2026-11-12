import {
  Body,
  ConflictException,
  Controller,
  Get,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { User, Withdrawal } from '@prisma/client';
import { CurrentUser, AuthGuard } from '../common/auth.guard.js';
import {
  LedgerAccount,
  LedgerEntryType,
  WithdrawalStatus,
} from '../common/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import { LedgerService } from './ledger.service.js';
import { WithdrawalInputDto } from './wallet.dto.js';

export interface WalletSummaryDto {
  balanceMinor: number;
  monthIncomeMinor: number;
  withdrawableMinor: number;
}

export interface WithdrawalDto {
  id: string;
  amountMinor: number;
  status: string;
  createdAt: Date;
}

@Controller('wallet')
@UseGuards(AuthGuard)
export class WalletController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledgerService: LedgerService,
  ) {}

  @Get()
  async getSummary(@CurrentUser() user: User): Promise<WalletSummaryDto> {
    const [balance, monthIncome] = await Promise.all([
      this.ledgerService.walletBalance(user.id),
      this.ledgerService.monthIncome(user.id),
    ]);
    return {
      balanceMinor: balance,
      monthIncomeMinor: monthIncome,
      // Demo: the full balance is withdrawable. Production may hold back
      // amounts under dispute or pending clearing windows.
      withdrawableMinor: balance,
    };
  }

  @Get('withdrawals')
  async listWithdrawals(@CurrentUser() user: User): Promise<WithdrawalDto[]> {
    const rows = await this.prisma.withdrawal.findMany({
      where: { userId: user.id },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map(WalletController.toWithdrawalDto);
  }

  @Post('withdrawals')
  async requestWithdrawal(
    @CurrentUser() user: User,
    @Body() input: WithdrawalInputDto,
  ): Promise<WithdrawalDto> {
    const withdrawal = await this.prisma.$transaction(async (tx) => {
      // Balance check and debit in one transaction. PRODUCTION: run at
      // SERIALIZABLE isolation (Postgres) to rule out concurrent overdrafts.
      const balance = await this.ledgerService.walletBalance(user.id, tx);
      if (input.amountMinor > balance) {
        throw new ConflictException('Insufficient balance');
      }
      await this.ledgerService.postEntries(tx, [
        {
          account: LedgerAccount.userWallet,
          entryType: LedgerEntryType.withdrawal,
          amountMinor: -input.amountMinor,
          userId: user.id,
        },
      ]);
      return tx.withdrawal.create({
        data: {
          userId: user.id,
          amountMinor: input.amountMinor,
          status: WithdrawalStatus.pending,
        },
      });
    });
    return WalletController.toWithdrawalDto(withdrawal);
  }

  private static toWithdrawalDto(row: Withdrawal): WithdrawalDto {
    return {
      id: row.id,
      amountMinor: row.amountMinor,
      status: row.status,
      createdAt: row.createdAt,
    };
  }
}
