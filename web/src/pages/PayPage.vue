<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { cancel, getOrder, pay, peerOf } from '@/api/orders';
import AppAvatar from '@/components/AppAvatar.vue';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { formatDateTime, formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type { LiveOrder } from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();

const orderId = route.params.id as string;

const order = ref<LiveOrder | null>(null);
const busy = ref(false);

const peer = computed(() =>
  order.value ? peerOf(order.value, session.userId) : null,
);

onMounted(async () => {
  try {
    const fresh = await getOrder(orderId);
    // A stale pay link (already paid, cancelled, expired) must not
    // render a payable form: the room is the true home of this order.
    if (fresh.status !== 'AWAITING_PAYMENT') {
      await router.replace(`/orders/${orderId}`);
      return;
    }
    order.value = fresh;
  } catch {
    showToast(strings.errorNetwork);
  }
});

function planWhen(o: LiveOrder): string {
  if (!o.planAt) return '';
  const when = formatDateTime(o.planAt);
  return o.planDurationMinutes > 0
    ? `${when} · ${strings.durationAbout(o.planDurationMinutes)}`
    : when;
}

async function doPay(): Promise<void> {
  busy.value = true;
  try {
    const paid = await pay(orderId);
    showToast(strings.paymentDoneSnack);
    await router.replace(`/orders/${paid.id}`);
  } catch {
    busy.value = false;
    showToast(strings.paymentFailedSnack);
  }
}

/**
 * Backing out of an unpaid deal is free: no money moved, the pitch or
 * post goes straight back on the market.
 */
async function cancelOrder(): Promise<void> {
  busy.value = true;
  try {
    await cancel(orderId);
    showToast(strings.unpaidCancelledSnack);
    router.back();
  } catch {
    showToast(strings.errorGeneric);
    busy.value = false;
  }
}
</script>

<template>
  <div class="pay-page">
    <PageHeader :title="strings.paymentTitle" />

    <div v-if="!order || !peer" class="loading">…</div>

    <template v-else>
      <div class="content">
        <!-- Who you are meeting: the deal is with a person, not an order id. -->
        <section class="peer-card">
          <div class="peer-row">
            <AppAvatar :url="peer.avatarUrl" :name="peer.name" :size="44" />
            <div class="peer-text">
              <span class="peer-name">{{ peer.name }}</span>
              <span v-if="peer.meta" class="peer-meta">{{ peer.meta }}</span>
            </div>
          </div>
          <!-- The locked plan: a concrete place and time, not an abstract match. -->
          <template v-if="order.planPlace">
            <hr class="rule" />
            <p class="plan-place">{{ order.planPlace }}</p>
            <p v-if="order.planAt" class="plan-when">{{ planWhen(order) }}</p>
            <p v-if="order.planNote" class="plan-note">{{ order.planNote }}</p>
          </template>
        </section>

        <div class="fee-row">
          <span class="fee-label">{{ strings.paymentFeeLabel }}</span>
          <span class="fee-amount">{{ formatMoney(order.feeAmount) }}</span>
        </div>

        <div class="escrow-note">
          {{ strings.paymentEscrowNote }}
        </div>

        <div class="method-row">
          <span class="method-label">{{ strings.paymentMethodDemo }}</span>
          <span class="method-check">✓</span>
        </div>
      </div>

      <div class="footer">
        <button class="btn-primary" :disabled="busy" @click="doPay">
          {{
            busy
              ? strings.paymentPaying
              : strings.paymentPayCta(formatMoney(order.feeAmount))
          }}
        </button>
        <button class="cancel-link" :disabled="busy" @click="cancelOrder">
          {{ strings.paymentCancelOrderCta }}
        </button>
      </div>
    </template>
  </div>
</template>

<style scoped>
.pay-page {
  min-height: 100dvh;
  background: var(--color-background);
  display: flex;
  flex-direction: column;
}

.loading {
  padding-top: 100px;
  text-align: center;
  color: var(--color-text-hint);
}

.content {
  flex: 1;
  padding: 8px 24px 16px;
}

.peer-card {
  padding: 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
}

.peer-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.peer-text {
  display: flex;
  flex-direction: column;
}

.peer-name {
  font-size: 15.5px;
  font-weight: 700;
}

.peer-meta {
  font-size: 12.5px;
  color: var(--color-text-secondary);
}

.rule {
  border: none;
  border-top: 1px solid var(--color-divider);
  margin: 14px 0;
}

.plan-place {
  margin: 0;
  font-size: 14.5px;
  font-weight: 700;
}

.plan-when {
  margin: 3px 0 0;
  font-size: 12.5px;
  color: var(--color-text-secondary);
}

.plan-note {
  margin: 8px 0 0;
  font-size: 13px;
  line-height: 1.45;
  color: var(--color-text-secondary);
}

.fee-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 20px;
}

.fee-label {
  font-size: 13px;
  color: var(--color-text-secondary);
}

.fee-amount {
  font-size: 26px;
  font-weight: 800;
}

.escrow-note {
  margin-top: 16px;
  padding: 13px;
  border-radius: 14px;
  background: var(--color-accent-soft);
  font-size: 12px;
  line-height: 1.5;
  color: var(--color-text-secondary);
}

.method-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 14px;
}

.method-label {
  font-size: 13px;
  font-weight: 600;
}

.method-check {
  color: var(--color-accent);
  font-weight: 700;
}

.footer {
  padding: 8px 24px 16px;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.cancel-link {
  font-size: 12.5px;
  color: var(--color-text-hint);
  padding: 6px;
}
</style>
