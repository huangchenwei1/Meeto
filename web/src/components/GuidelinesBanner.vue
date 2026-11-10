<script setup lang="ts">
import { useRouter } from 'vue-router';

import { strings } from '@/constants/strings';

/**
 * Community guidelines strip: a single light-gray line under the page
 * head — the safety pledge plus a chevron into the full guidelines
 * page. Deliberately quiet; it reassures without taking over the feed.
 */
const router = useRouter();
</script>

<template>
  <button class="guidelines-strip" @click="router.push('/guidelines')">
    <svg
      class="strip-icon"
      viewBox="0 0 24 24"
      width="14"
      height="14"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
    >
      <path d="M12 3l7 3v5c0 4.5-3 8.5-7 10-4-1.5-7-5.5-7-10V6l7-3z" />
      <path d="M9 12l2 2 4-4" />
    </svg>
    <span class="strip-text">
      {{ strings.bannerTitle }} · {{ strings.bannerSub }}
    </span>
    <span class="strip-chevron">›</span>
  </button>
</template>

<style scoped>
.guidelines-strip {
  display: flex;
  align-items: center;
  gap: 7px;
  width: calc(100% - 40px);
  margin: 0 20px 12px;
  padding: 9px 12px;
  border-radius: 10px;
  background: var(--color-surface);
  text-align: left;
}

.strip-icon {
  flex-shrink: 0;
  color: var(--color-accent);
}

.strip-text {
  flex: 1;
  min-width: 0;
  font-size: 12px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.strip-chevron {
  flex-shrink: 0;
  font-size: 15px;
  color: var(--color-text-hint);
}
</style>
