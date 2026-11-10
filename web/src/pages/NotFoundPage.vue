<script setup lang="ts">
import { useRouter } from 'vue-router';

import { strings } from '@/constants/strings';

const router = useRouter();
</script>

<template>
  <div class="not-found-page">
    <p class="mark">🧭</p>
    <h1 class="title">{{ strings.notFoundTitle }}</h1>
    <p class="body">{{ strings.notFoundBody }}</p>
    <button class="btn-primary" @click="router.replace('/hall')">
      {{ strings.backToHallCta }}
    </button>
  </div>
</template>

<style scoped>
.not-found-page {
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 0 32px;
  background: var(--color-background);
  text-align: center;
}

.mark {
  margin: 0;
  font-size: 44px;
}

.title {
  margin: 8px 0 0;
  font-size: 18px;
  font-weight: 700;
}

.body {
  margin: 0 0 20px;
  font-size: 13.5px;
  color: var(--color-text-secondary);
}

.btn-primary {
  width: auto;
  padding: 12px 36px;
}
</style>
