<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { fetchConversations, listMine } from '@/api/orders';
import { strings } from '@/constants/strings';
import { actionableCount, unreadChatCount } from '@/stores/badge';
import { useSessionStore } from '@/stores/session';
import type { LiveOrder } from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();

// The Messages tab badge must stay fresh while the user browses other
// tabs, so the shell polls the conversation list itself (the chats page
// refines the same store faster while open).
let unreadTimer: number | undefined;

async function pollUnread(): Promise<void> {
  try {
    const list = await fetchConversations();
    unreadChatCount.value = list.reduce((sum, c) => sum + c.unreadCount, 0);
  } catch {
    // Keep the last known count; the next poll retries.
  }
}

// The deal notice bar: a persistent strip above the tab bar for the
// moment a deal forms. It is not a dismissable notification but a
// projection of real state — it stands until the state resolves (the
// payer pays; the earner opens the new room), so it cannot be swiped
// away with the thing left undone.
interface DealNotice {
  kind: 'ONGOING' | 'PAY' | 'GREET' | 'LOBBY';
  orderId: string;
}

const dealNotices = ref<DealNotice[]>([]);

async function pollDeals(): Promise<void> {
  try {
    const orders = await listMine(true);
    const me = session.userId;
    // A running activity owns the strip for BOTH sides: the user is out
    // meeting their partner right now, so the room shortcut beats
    // everything else. It stands until the service settles.
    const ongoing = orders
      .filter((o: LiveOrder) => o.status === 'ACTIVE' && o.startedAt !== null)
      .map((o): DealNotice => ({ kind: 'ONGOING', orderId: o.id }));
    // Paying is the urgent half of a fresh deal (unpaid deals expire).
    const pay = orders
      .filter((o) => o.status === 'AWAITING_PAYMENT' && o.payer.id === me)
      .map((o): DealNotice => ({ kind: 'PAY', orderId: o.id }));
    // A live deal keeps its strip for BOTH sides until the activity ends:
    // entering the room never dismisses it, only settlement does. The
    // wording softens once the viewer has been inside ("go say hi" ->
    // a plain room shortcut).
    const live = orders
      .filter((o: LiveOrder) => o.status === 'ACTIVE' && o.startedAt === null)
      .map(
        (o): DealNotice => ({
          kind: o.viewerEnteredRoom ? 'LOBBY' : 'GREET',
          orderId: o.id,
        }),
      );
    dealNotices.value = [...ongoing, ...pay, ...live];
  } catch {
    // Keep the last known state; the next poll retries.
  }
}

const dealNotice = computed(() => dealNotices.value[0] ?? null);

const DEAL_NOTICE_LABELS: Record<DealNotice['kind'], string> = {
  ONGOING: strings.dealNoticeOngoing,
  PAY: strings.dealNoticePay,
  GREET: strings.dealNoticeGreet,
  LOBBY: strings.dealNoticeActive,
};

function openDealNotice(): void {
  const notice = dealNotice.value;
  if (!notice) return;
  void router.push(
    notice.kind === 'PAY'
      ? `/orders/${notice.orderId}/pay`
      : `/orders/${notice.orderId}`,
  );
}

onMounted(() => {
  void pollUnread();
  void pollDeals();
  unreadTimer = window.setInterval(() => {
    void pollUnread();
    void pollDeals();
  }, 5000);
});

onUnmounted(() => window.clearInterval(unreadTimer));

const tabs = [
  { name: 'hall', icon: 'compass' },
  { name: 'chats', icon: 'chat' },
  { name: 'activities', icon: 'calendar' },
  { name: 'me', icon: 'user' },
] as const;
</script>

<template>
  <div class="shell">
    <main class="tab-content">
      <RouterView />
    </main>
    <button v-if="dealNotice" class="deal-notice" @click="openDealNotice">
      <span class="deal-dot" />
      <span class="deal-text">
        {{ DEAL_NOTICE_LABELS[dealNotice.kind] }}
      </span>
      <span v-if="dealNotices.length > 1" class="deal-more">
        {{ strings.dealNoticeMore(dealNotices.length - 1) }}
      </span>
      <span class="deal-chevron">›</span>
    </button>
    <nav class="tab-bar">
      <RouterLink
        v-for="tab in tabs"
        :key="tab.name"
        :to="{ name: tab.name }"
        class="tab-item"
        :class="{ active: route.name === tab.name }"
      >
        <span class="icon-wrap">
          <svg
            v-if="tab.icon === 'compass'"
            viewBox="0 0 24 24" width="24" height="24" fill="none"
            stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"
          >
            <circle cx="12" cy="12" r="9" />
            <path d="M15.5 8.5l-2 5-5 2 2-5 5-2z" />
          </svg>
          <svg
            v-else-if="tab.icon === 'chat'"
            viewBox="0 0 24 24" width="24" height="24" fill="none"
            stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"
          >
            <path d="M21 12a8 8 0 0 1-8 8H4l1.6-3.2A8 8 0 1 1 21 12z" />
          </svg>
          <svg
            v-else-if="tab.icon === 'calendar'"
            viewBox="0 0 24 24" width="24" height="24" fill="none"
            stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"
          >
            <rect x="3" y="5" width="18" height="16" rx="3" />
            <path d="M8 3v4M16 3v4M3 10h18" />
          </svg>
          <svg
            v-else
            viewBox="0 0 24 24" width="24" height="24" fill="none"
            stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"
          >
            <circle cx="12" cy="8" r="4" />
            <path d="M4 21c0-4 3.6-6.5 8-6.5s8 2.5 8 6.5" />
          </svg>
          <span
            v-if="tab.name === 'activities' && actionableCount > 0"
            class="badge"
          >
            {{ actionableCount }}
          </span>
          <span
            v-if="tab.name === 'chats' && unreadChatCount > 0"
            class="badge"
          >
            {{ unreadChatCount }}
          </span>
        </span>
      </RouterLink>
    </nav>
  </div>
</template>

<style scoped>
.shell {
  display: flex;
  flex-direction: column;
  min-height: 100dvh;
}

.tab-content {
  flex: 1;
  padding-bottom: 64px;
  background: var(--color-background);
}

.deal-notice {
  position: fixed;
  bottom: calc(64px + env(safe-area-inset-bottom) + 10px);
  left: 50%;
  transform: translateX(-50%);
  width: calc(100% - 32px);
  max-width: calc(480px - 32px);
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 12px 14px;
  border-radius: 14px;
  background: var(--color-accent);
  color: #fff;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.18);
  z-index: 60;
  text-align: left;
}

.deal-dot {
  flex-shrink: 0;
  width: 8px;
  height: 8px;
  border-radius: 999px;
  background: #fff;
  animation: deal-pulse 1.6s ease-in-out infinite;
}

@keyframes deal-pulse {
  0%,
  100% {
    opacity: 1;
  }
  50% {
    opacity: 0.35;
  }
}

.deal-text {
  flex: 1;
  min-width: 0;
  font-size: 13.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.deal-more {
  flex-shrink: 0;
  font-size: 11.5px;
  font-weight: 600;
  opacity: 0.85;
}

.deal-chevron {
  flex-shrink: 0;
  font-size: 16px;
  opacity: 0.9;
}

.tab-bar {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  height: 64px;
  display: flex;
  background: var(--color-background);
  border-top: 1px solid var(--color-divider);
  z-index: 50;
  padding-bottom: env(safe-area-inset-bottom);
}

.tab-item {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-hint);
}

.tab-item.active {
  color: var(--color-accent);
}

.icon-wrap {
  position: relative;
  display: flex;
}

.badge {
  position: absolute;
  top: -5px;
  right: -9px;
  min-width: 16px;
  height: 16px;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--color-danger);
  color: #fff;
  font-size: 10px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}

</style>
