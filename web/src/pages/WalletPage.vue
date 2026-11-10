<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { ApiError } from '@/api/client';
import { fetchWallet, fetchWithdrawals, requestWithdrawal } from '@/api/users';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { confirmDialog } from '@/utils/confirm';
import { formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type { WalletSummary, WithdrawalRecord } from '@/types/models';

const router = useRouter();

const wallet = ref<WalletSummary | null>(null);
const withdrawals = ref<WithdrawalRecord[]>([]);
const busy = ref(false);
const sheetOpen = ref(false);
const amountInput = ref('');

async function load(): Promise<void> {
  const [w, records] = await Promise.all([fetchWallet(), fetchWithdrawals()]);
  wallet.value = w;
  withdrawals.value = records;
}

onMounted(() => void load());

function openSheet(): void {
  if (!wallet.value || wallet.value.withdrawable <= 0) return;
  amountInput.value = String(wallet.value.withdrawable);
  sheetOpen.value = true;
}

async function submitWithdraw(): Promise<void> {
  const amount = Number.parseInt(amountInput.value.trim(), 10);
  if (!Number.isFinite(amount) || amount <= 0) return;
  sheetOpen.value = false;
  busy.value = true;
  try {
    await requestWithdrawal(amount);
    showToast(strings.withdrawSubmitted);
    await load();
  } catch (error) {
    if (error instanceof ApiError && error.verificationRequired) {
      const go = await confirmDialog({
        title: strings.verifyDialogTitle,
        body: strings.verifyDialogBody,
        yesLabel: strings.verifyNow,
        noLabel: strings.verifyLater,
      });
      if (go) void router.push('/verification');
    } else {
      showToast(strings.withdrawFailed);
    }
  } finally {
    busy.value = false;
  }
}

function formatDate(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
</script>

<template>
  <div class="wallet-page">
    <PageHeader :title="strings.walletTitle" />

    <div v-if="!wallet" class="loading">…</div>

    <div v-else class="content">
      <section class="summary-card">
        <p class="wallet-label">{{ strings.walletLabel }}</p>
        <p class="wallet-amount">{{ formatMoney(wallet.monthIncome) }}</p>
        <div class="wallet-foot">
          <span class="wallet-sub">
            {{ strings.walletWithdrawable(formatMoney(wallet.withdrawable)) }}
          </span>
          <button
            class="withdraw-btn"
            :disabled="busy || wallet.withdrawable <= 0"
            @click="openSheet"
          >
            {{ strings.withdraw }}
          </button>
        </div>
      </section>

      <h2 class="history-title">{{ strings.withdrawHistoryTitle }}</h2>

      <p v-if="withdrawals.length === 0" class="history-empty">
        {{ strings.withdrawHistoryEmpty }}
      </p>

      <div
        v-for="record in withdrawals"
        :key="record.id"
        class="withdrawal-tile"
      >
        <div class="tile-text">
          <span class="tile-amount">{{ formatMoney(record.amount) }}</span>
          <span class="tile-date">{{ formatDate(record.createdAt) }}</span>
        </div>
        <span
          class="tile-status"
          :class="record.status === 'PENDING' ? 'pending' : 'paid'"
        >
          {{
            record.status === 'PENDING'
              ? strings.withdrawalPending
              : strings.withdrawalPaid
          }}
        </span>
      </div>
    </div>

    <!-- Withdrawal amount sheet: the ledger is debited immediately. -->
    <Teleport to="body">
      <div v-if="sheetOpen" class="sheet-mask" @click.self="sheetOpen = false">
        <div class="sheet">
          <h3 class="sheet-title">{{ strings.withdrawSheetTitle }}</h3>
          <p class="sheet-sub">
            {{ strings.withdrawSheetSub(formatMoney(wallet!.withdrawable)) }}
          </p>
          <div class="amount-row">
            <span class="currency">₱</span>
            <input
              v-model="amountInput"
              class="text-field amount-field"
              inputmode="numeric"
              autofocus
              @keyup.enter="submitWithdraw"
            />
          </div>
          <button class="btn-primary sheet-cta" @click="submitWithdraw">
            {{ strings.withdraw }}
          </button>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.wallet-page {
  min-height: 100dvh;
  background: var(--color-background);
}

.loading {
  padding: 80px 0 0;
  text-align: center;
  color: var(--color-text-secondary);
}

.content {
  padding: 16px;
}

.summary-card {
  padding: 18px;
  background: var(--color-dark-card);
  border-radius: 18px;
}

.wallet-label {
  margin: 0;
  font-size: 12.5px;
  color: var(--color-on-dark-secondary);
}

.wallet-amount {
  margin: 10px 0;
  font-size: 30px;
  font-weight: 800;
  color: #fff;
}

.wallet-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.wallet-sub {
  font-size: 11.5px;
  color: var(--color-on-dark-secondary);
}

.withdraw-btn {
  padding: 8px 18px;
  border-radius: 999px;
  background: #fff;
  color: var(--color-text-primary);
  font-size: 12.5px;
  font-weight: 700;
  flex-shrink: 0;
}

.withdraw-btn:disabled {
  opacity: 0.5;
}

.history-title {
  margin: 24px 0 8px;
  font-size: 15px;
  font-weight: 800;
}

.history-empty {
  padding: 24px 0;
  text-align: center;
  font-size: 13px;
  color: var(--color-text-hint);
}

.withdrawal-tile {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  padding: 12px 14px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
}

.tile-text {
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.tile-amount {
  font-size: 15px;
  font-weight: 800;
}

.tile-date {
  font-size: 11.5px;
  color: var(--color-text-hint);
}

.tile-status {
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 600;
}

.tile-status.pending {
  background: #fef3c7;
  color: #92400e;
}

.tile-status.paid {
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.sheet-mask {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 60;
}

.sheet {
  width: 100%;
  max-width: 480px;
  background: var(--color-background);
  border-radius: 20px 20px 0 0;
  padding: 24px 24px calc(24px + env(safe-area-inset-bottom));
}

.sheet-title {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
}

.sheet-sub {
  margin: 6px 0 16px;
  font-size: 13px;
  color: var(--color-text-secondary);
}

.amount-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.currency {
  font-size: 18px;
  font-weight: 700;
}

.amount-field {
  flex: 1;
}

.sheet-cta {
  width: 100%;
  margin-top: 16px;
}
</style>
