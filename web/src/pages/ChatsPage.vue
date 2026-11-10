<script setup lang="ts">
import { onActivated, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { fetchConversations } from '@/api/orders';
import AppAvatar from '@/components/AppAvatar.vue';
import VerifiedBadge from '@/components/VerifiedBadge.vue';
import { strings } from '@/constants/strings';
import { unreadChatCount } from '@/stores/badge';
import { relativeTime } from '@/utils/format';
import type { ConversationItem } from '@/types/models';

/**
 * The contact-style conversation list: one row per PARTNER, because the
 * relationship outlives any single activity — settled chats stay open
 * and rebooking happens inside them. Tapping a row opens the partner's
 * current room (the live deal when one exists, else the latest settled
 * one). Deal management itself stays on the activities board.
 */
const router = useRouter();

const conversations = ref<ConversationItem[]>([]);
const loaded = ref(false);

let pollTimer: number | undefined;

async function poll(): Promise<void> {
  try {
    conversations.value = await fetchConversations();
    // Same data the tab badge runs on; refresh it while we are here so
    // reading a room clears the badge without waiting for the shell poll.
    unreadChatCount.value = conversations.value.reduce(
      (sum, c) => sum + c.unreadCount,
      0,
    );
    loaded.value = true;
  } catch {
    // Keep the last known list; the next poll retries.
  }
}

onMounted(() => {
  void poll();
  pollTimer = window.setInterval(() => void poll(), 3000);
});

onActivated(() => void poll());

onUnmounted(() => window.clearInterval(pollTimer));

/** Card messages carry JSON, so previews label them instead. */
function previewOf(c: ConversationItem): string {
  if (c.lastMessageKind === 'PLAN') return strings.msgPreviewPlan;
  if (c.lastMessageKind === 'REQUEST') return strings.msgPreviewRequest;
  return c.lastMessageText;
}

function openRoom(c: ConversationItem): void {
  void router.push(`/orders/${c.roomOrderId}`);
}
</script>

<template>
  <div class="chats-page">
    <header class="page-head">
      <h1 class="page-title">{{ strings.tabChats }}</h1>
      <p class="page-hint">{{ strings.chatsHint }}</p>
    </header>

    <div v-if="!loaded" class="loading">…</div>

    <div v-else-if="conversations.length === 0" class="empty">
      {{ strings.chatsEmpty }}
    </div>

    <div v-else class="list">
      <button
        v-for="c in conversations"
        :key="c.peerId"
        class="row"
        @click="openRoom(c)"
      >
        <AppAvatar :url="c.peerAvatarUrl" :name="c.peerName" :size="48" />
        <div class="row-main">
          <div class="row-top">
            <span class="row-name">
              {{ c.peerName }}
              <VerifiedBadge v-if="c.peerVerified" />
            </span>
            <span v-if="c.lastMessageAt" class="row-time">
              {{ relativeTime(c.lastMessageAt) }}
            </span>
          </div>
          <div class="row-bottom">
            <span class="row-preview">{{ previewOf(c) }}</span>
            <span v-if="c.unreadCount > 0" class="row-unread">
              {{ c.unreadCount }}
            </span>
            <span v-else-if="c.hasLiveOrder" class="row-live">
              {{ strings.chatLiveBadge }}
            </span>
          </div>
        </div>
      </button>
    </div>
  </div>
</template>

<style scoped>
.chats-page {
  min-height: calc(100dvh - 64px);
  background: var(--color-background);
  padding-bottom: 20px;
}

.page-head {
  padding: 14px 20px 10px;
}

.page-head .page-title {
  font-size: 20px;
}

.page-hint {
  margin: 6px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
}

.loading,
.empty {
  padding: 80px 32px 0;
  text-align: center;
  color: var(--color-text-secondary);
  font-size: 15px;
}

.list {
  display: flex;
  flex-direction: column;
}

.row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 20px;
  text-align: left;
  background: transparent;
}

.row:active {
  background: var(--color-surface);
}

.row-main {
  flex: 1;
  min-width: 0;
  border-bottom: 1px solid var(--color-divider);
  padding-bottom: 12px;
  margin-bottom: -12px;
}

.row-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.row-name {
  font-size: 15.5px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.row-time {
  flex-shrink: 0;
  font-size: 11.5px;
  color: var(--color-text-hint);
}

.row-bottom {
  margin-top: 3px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.row-preview {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.row-unread {
  flex-shrink: 0;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: 999px;
  background: var(--color-danger);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
}

.row-live {
  flex-shrink: 0;
  font-size: 11px;
  font-weight: 700;
  color: var(--color-accent);
  background: var(--color-accent-soft);
  padding: 3px 8px;
  border-radius: 999px;
}
</style>
