import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import {
  LedgerAccount,
  LedgerEntryType,
} from '../common/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';

export interface LedgerPosting {
  account: LedgerAccount;
  entryType: LedgerEntryType;
  amountMinor: number;
  userId?: string;
  orderId?: string;
}

/// Append-only double-entry-style ledger. Balances are always derived by
/// summing entries — never stored — so the books stay auditable and any
/// balance can be recomputed from history.
@Injectable()
export class LedgerService {
  constructor(private readonly prisma: PrismaService) {}

  /// Posts a batch of entries inside the caller's transaction.
  async postEntries(
    tx: Prisma.TransactionClient,
    postings: LedgerPosting[],
  ): Promise<void> {
    await tx.ledgerEntry.createMany({
      data: postings.map((posting) => ({
        account: posting.account,
        entryType: posting.entryType,
        amountMinor: posting.amountMinor,
        userId: posting.userId ?? null,
        orderId: posting.orderId ?? null,
      })),
    });
  }

  async walletBalance(
    userId: string,
    tx?: Prisma.TransactionClient,
  ): Promise<number> {
    const client = tx ?? this.prisma;
    const result = await client.ledgerEntry.aggregate({
      where: { account: LedgerAccount.userWallet, userId },
      _sum: { amountMinor: true },
    });
    return result._sum.amountMinor ?? 0;
  }

  async monthIncome(userId: string): Promise<number> {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const result = await this.prisma.ledgerEntry.aggregate({
      where: {
        account: LedgerAccount.userWallet,
        userId,
        entryType: LedgerEntryType.settleNet,
        createdAt: { gte: monthStart },
      },
      _sum: { amountMinor: true },
    });
    return result._sum.amountMinor ?? 0;
  }
}
