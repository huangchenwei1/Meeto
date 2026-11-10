<script setup lang="ts">
import { strings } from '@/constants/strings';
</script>

<template>
  <span class="verified-badge">
    <svg viewBox="0 0 24 24" width="11" height="11" fill="currentColor">
      <path
        d="M12 2l2.4 2.4 3.4-.5 1 3.3 3 1.7-1.3 3.1 1.3 3.1-3 1.7-1 3.3-3.4-.5L12 22l-2.4-2.4-3.4.5-1-3.3-3-1.7L3.5 12 2.2 8.9l3-1.7 1-3.3 3.4.5L12 2zm-1.2 13.6l5.2-5.2-1.4-1.4-3.8 3.8-1.6-1.6-1.4 1.4 3 3z"
      />
    </svg>
    {{ strings.verifiedLabel }}
  </span>
</template>

<style scoped>
.verified-badge {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 7px;
  border-radius: 999px;
  background: var(--color-accent-soft);
  color: var(--color-accent);
  font-size: 11px;
  font-weight: 600;
  white-space: nowrap;
}
</style>
