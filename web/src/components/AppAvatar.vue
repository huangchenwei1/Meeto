<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    url?: string;
    name?: string;
    size?: number;
  }>(),
  { url: '', name: '', size: 40 },
);

const initial = computed(() =>
  props.name.length > 0 ? props.name[0].toUpperCase() : '?',
);
</script>

<template>
  <div
    class="avatar"
    :style="{ width: `${size}px`, height: `${size}px`, fontSize: `${size * 0.4}px` }"
  >
    <img v-if="url" :src="url" :alt="name" />
    <span v-else>{{ initial }}</span>
  </div>
</template>

<style scoped>
.avatar {
  border-radius: 50%;
  overflow: hidden;
  background: var(--color-button-soft);
  color: var(--color-text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-weight: 600;
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
