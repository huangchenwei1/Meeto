<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { fetchPostsByAuthor } from '@/api/posts';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { relativeTime } from '@/utils/format';
import type { ActivityPost, PostStatus } from '@/types/models';

const router = useRouter();
const session = useSessionStore();

const posts = ref<ActivityPost[]>([]);
const loaded = ref(false);

/**
 * The management view, every status included: matched/cancelled posts
 * leave the public feed, so this page is the only way back into them.
 */
onMounted(async () => {
  posts.value = await fetchPostsByAuthor(session.userId);
  loaded.value = true;
});

const STATUS_PILLS: Record<PostStatus, { label: string; cls: string }> = {
  OPEN: { label: strings.postStatusOpen, cls: 'open' },
  PENDING_PAYMENT: { label: strings.statusAwaitingPayment, cls: 'pending' },
  MATCHED: { label: strings.postStatusMatched, cls: 'matched' },
  COMPLETED: { label: strings.statusCompleted, cls: 'closed' },
  CANCELLED: { label: strings.statusCancelled, cls: 'closed' },
};
</script>

<template>
  <div class="my-posts-page">
    <PageHeader :title="strings.menuMyPosts" />

    <div v-if="!loaded" class="loading">…</div>

    <div v-else-if="posts.length === 0" class="empty">
      {{ strings.myPostsEmpty }}
    </div>

    <div v-else class="list">
      <button
        v-for="post in posts"
        :key="post.id"
        class="post-row"
        @click="router.push(`/posts/${post.id}`)"
      >
        <img class="thumb" :src="post.imageUrl" alt="" />
        <div class="row-text">
          <div class="title-row">
            <span class="title">{{ post.title }}</span>
            <span class="pill" :class="STATUS_PILLS[post.status].cls">
              {{ STATUS_PILLS[post.status].label }}
            </span>
          </div>
          <p class="meta">
            {{ strings.sceneLabel(post.sceneTag) }} ·
            {{ relativeTime(post.createdAt) }}
          </p>
        </div>
        <span class="arrow">›</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.my-posts-page {
  min-height: 100dvh;
  background: var(--color-background);
}

.loading,
.empty {
  padding: 80px 32px 0;
  text-align: center;
  color: var(--color-text-secondary);
}

.list {
  padding: 8px 0 24px;
}

.post-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 12px 16px;
  text-align: left;
}

.post-row + .post-row {
  border-top: 1px solid var(--color-divider);
}

.thumb {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  object-fit: cover;
  flex-shrink: 0;
  background: var(--color-surface);
}

.row-text {
  flex: 1;
  min-width: 0;
}

.title-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.title {
  font-size: 15.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.pill {
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11.5px;
  font-weight: 600;
  flex-shrink: 0;
}

.pill.open {
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.pill.pending {
  background: #fef3c7;
  color: #92400e;
}

.pill.matched {
  background: #dbeafe;
  color: #1d4ed8;
}

.pill.closed {
  background: var(--color-surface);
  color: var(--color-text-secondary);
}

.meta {
  margin: 4px 0 0;
  font-size: 12.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.arrow {
  color: var(--color-text-hint);
  font-size: 18px;
}
</style>
