<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { beginEntry } from '@/api/auth';
import { INTRO_SEEN_KEY } from '@/constants/guest';
import { pathAfterEntry } from '@/utils/entryRoute';

const BOOT_HOLD_MS = 900;

const route = useRoute();
const router = useRouter();

let timer = 0;

onMounted(() => {
  const next = typeof route.query.next === 'string' ? route.query.next : '';
  const entryPromise = beginEntry();
  timer = window.setTimeout(() => {
    void entryPromise
      .then(async (entry) => {
        sessionStorage.setItem(INTRO_SEEN_KEY, '1');
        await router.replace(pathAfterEntry(entry, next));
      })
      .catch(() => {
        sessionStorage.removeItem(INTRO_SEEN_KEY);
      });
  }, BOOT_HOLD_MS);
});

onUnmounted(() => {
  if (timer) window.clearTimeout(timer);
});
</script>

<template>
  <div class="boot">
    <h1>Meeto</h1>
  </div>
</template>

<style scoped>
.boot {
  min-height: 100dvh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #ffffff;
}

h1 {
  margin: 0;
  font-size: 40px;
  font-weight: 800;
  letter-spacing: -0.03em;
  color: var(--color-text-primary);
}
</style>
