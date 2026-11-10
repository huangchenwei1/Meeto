<script setup lang="ts">
import { useRouter } from 'vue-router';

defineProps<{ title?: string }>();

const router = useRouter();

function goBack(): void {
  if (window.history.length > 1) {
    router.back();
  } else {
    void router.replace('/hall');
  }
}
</script>

<template>
  <header class="page-header">
    <button class="back-btn" aria-label="back" @click="goBack">
      <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M15 18l-6-6 6-6" />
      </svg>
    </button>
    <h1 class="title">{{ title ?? '' }}</h1>
    <div class="trailing"><slot name="trailing" /></div>
  </header>
</template>

<style scoped>
.page-header {
  position: sticky;
  top: 0;
  z-index: 20;
  display: flex;
  align-items: center;
  height: 52px;
  padding: 0 8px;
  background: var(--color-background);
}

.back-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-primary);
}

.title {
  flex: 1;
  text-align: center;
  font-size: 16px;
  font-weight: 700;
  margin: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.trailing {
  min-width: 40px;
  display: flex;
  justify-content: flex-end;
  align-items: center;
}
</style>
