<script setup lang="ts">
import ConfirmHost from '@/components/ConfirmHost.vue';
import ToastHost from '@/components/ToastHost.vue';
</script>

<template>
  <div class="app-frame">
    <RouterView />
    <ToastHost />
    <ConfirmHost />
  </div>
</template>

<style scoped>
/* Mobile-first: the app renders as a centered phone-width column on
   desktop, full-bleed on actual phones. */
.app-frame {
  max-width: 480px;
  margin: 0 auto;
  min-height: 100dvh;
  background: var(--color-background);
  position: relative;
  box-shadow: 0 0 24px rgb(0 0 0 / 6%);
}
</style>
