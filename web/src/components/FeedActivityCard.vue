<script setup lang="ts">
import AppAvatar from '@/components/AppAvatar.vue';
import { realPersonVerificationEnabled } from '@/constants/features';
import { relativeTime } from '@/utils/format';

defineProps<{
  avatarUrl: string;
  authorName: string;
  authorVerified: boolean;
  metaLine: string;
  createdAt: Date;
  imageUrl: string;
  /** Already-localized scene display label; leads the info line. */
  sceneLabel: string;
  title: string;
  description: string;
  /** Info line after the scene label, e.g. "今天下午 · 江汉路 · 2 人已报名". */
  infoText?: string;
  /** Bottom-left of the activity box, e.g. the budget. */
  footerText?: string;
}>();

defineEmits<{ tap: [] }>();
</script>

<template>
  <article class="feed-card" @click="$emit('tap')">
    <header class="author-row">
      <AppAvatar :url="avatarUrl" :name="authorName" :size="38" />
      <div class="author-info">
        <div class="name-row">
          <span class="name">{{ authorName }}</span>
          <svg
            v-if="realPersonVerificationEnabled && authorVerified"
            class="verify-icon"
            viewBox="0 0 24 24" width="14" height="14" fill="currentColor"
          >
            <path d="M12 2l2.4 2.4 3.4-.5 1 3.3 3 1.7-1.3 3.1 1.3 3.1-3 1.7-1 3.3-3.4-.5L12 22l-2.4-2.4-3.4.5-1-3.3-3-1.7L3.5 12 2.2 8.9l3-1.7 1-3.3 3.4.5L12 2zm-1.2 13.6l5.2-5.2-1.4-1.4-3.8 3.8-1.6-1.6-1.4 1.4 3 3z" />
          </svg>
        </div>
        <span v-if="metaLine" class="meta">{{ metaLine }}</span>
      </div>
      <span class="time">{{ relativeTime(createdAt) }}</span>
    </header>

    <!-- The activity box: what you are actually buying. -->
    <div class="activity-box">
      <div class="box-main">
        <img v-if="imageUrl" class="thumb" :src="imageUrl" alt="" />
        <div class="box-text">
          <h3 class="title">{{ title }}</h3>
          <p v-if="description" class="desc">{{ description }}</p>
          <p class="info-line">
            <span class="scene">{{ sceneLabel }}</span>
            <span v-if="infoText" class="info"> · {{ infoText }}</span>
          </p>
        </div>
        <!-- No footer text (e.g. a host pitch carries no price): skip the
             footer row entirely and seat the action beside the content. -->
        <div v-if="!footerText" class="main-action">
          <slot name="action" />
        </div>
      </div>
      <footer v-if="footerText" class="box-footer">
        <span class="footer-money">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round">
            <rect x="3" y="6" width="18" height="13" rx="3" />
            <path d="M3 10h18M16 15h2" />
          </svg>
          {{ footerText }}
        </span>
        <span class="spacer"></span>
        <slot name="action" />
      </footer>
    </div>
  </article>
</template>

<style scoped>
.feed-card {
  cursor: pointer;
}

.author-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.author-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 5px;
  min-width: 0;
}

.name {
  font-size: 14.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.verify-icon {
  color: var(--color-accent);
  flex-shrink: 0;
}

.meta {
  font-size: 12px;
  color: var(--color-text-hint);
}

.time {
  font-size: 11.5px;
  color: var(--color-text-hint);
  flex-shrink: 0;
}

.activity-box {
  margin-top: 10px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-background);
}

.box-main {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.thumb {
  width: 72px;
  height: 72px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
}

.box-text {
  flex: 1;
  min-width: 0;
}

.title {
  font-size: 15px;
  font-weight: 700;
  line-height: 1.3;
  margin: 0;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.desc {
  margin: 4px 0 0;
  font-size: 12.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.info-line {
  margin: 6px 0 0;
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.scene {
  font-weight: 600;
  color: var(--color-accent);
}

.info {
  color: var(--color-text-hint);
}

.main-action {
  flex-shrink: 0;
  align-self: center;
}

.main-action:empty {
  display: none;
}

.box-footer {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 12px;
}

.footer-money {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 13px;
  font-weight: 700;
}

.footer-money svg {
  color: var(--color-text-secondary);
}

.spacer {
  flex: 1;
}
</style>
