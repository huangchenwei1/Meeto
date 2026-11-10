<script setup lang="ts">
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
</script>

<template>
  <div class="guidelines-page">
    <PageHeader :title="strings.guidelinesTitle" />

    <div class="content">
      <p class="intro">{{ strings.guidelinesIntro }}</p>

      <ol class="rules">
        <li
          v-for="([title, body], index) in strings.guidelinesRules"
          :key="index"
          class="rule"
        >
          <span class="rule-index">{{ index + 1 }}</span>
          <div class="rule-text">
            <p class="rule-title">{{ title }}</p>
            <p class="rule-body">{{ body }}</p>
          </div>
        </li>
      </ol>

      <p class="footer">{{ strings.guidelinesFooter }}</p>
    </div>
  </div>
</template>

<style scoped>
.guidelines-page {
  min-height: 100dvh;
  background: var(--color-background);
}

.content {
  padding: 8px 20px 40px;
}

.intro {
  margin: 0 0 20px;
  font-size: 14px;
  line-height: 1.7;
  color: var(--color-text-secondary);
}

.rules {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.rule {
  display: flex;
  gap: 14px;
}

.rule-index {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: var(--color-accent-soft);
  color: var(--color-accent);
  font-size: 13px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.rule-title {
  margin: 2px 0 4px;
  font-size: 14.5px;
  font-weight: 700;
}

.rule-body {
  margin: 0;
  font-size: 13px;
  line-height: 1.6;
  color: var(--color-text-secondary);
}

.footer {
  margin: 28px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
  text-align: center;
}
</style>
