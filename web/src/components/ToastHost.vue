<script setup lang="ts">
import { toasts } from '@/utils/toast';
</script>

<template>
  <TransitionGroup name="toast" tag="div" class="toast-host">
    <div v-for="toast in toasts" :key="toast.id" class="toast">
      {{ toast.text }}
    </div>
  </TransitionGroup>
</template>

<style scoped>
.toast-host {
  position: fixed;
  bottom: 88px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  z-index: 1000;
  width: min(440px, calc(100vw - 40px));
  pointer-events: none;
}

.toast {
  background: var(--color-dark-card);
  color: #fff;
  font-size: 13.5px;
  padding: 11px 18px;
  border-radius: 12px;
  max-width: 100%;
  text-align: center;
  box-shadow: 0 6px 20px rgb(0 0 0 / 20%);
}

.toast-enter-active,
.toast-leave-active {
  transition: all 0.25s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
