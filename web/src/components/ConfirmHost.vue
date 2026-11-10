<script setup lang="ts">
import { activeConfirm } from '@/utils/confirm';
</script>

<template>
  <Teleport to="body">
    <div v-if="activeConfirm" class="overlay" @click.self="activeConfirm.resolve(false)">
      <div class="dialog">
        <h3 class="title">{{ activeConfirm.title }}</h3>
        <p class="body">{{ activeConfirm.body }}</p>
        <div class="actions">
          <button class="btn no" @click="activeConfirm.resolve(false)">
            {{ activeConfirm.noLabel }}
          </button>
          <button
            class="btn yes"
            :class="{ danger: activeConfirm.danger }"
            @click="activeConfirm.resolve(true)"
          >
            {{ activeConfirm.yesLabel }}
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  background: rgb(0 0 0 / 40%);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1100;
  padding: 32px;
}

.dialog {
  background: #fff;
  border-radius: 20px;
  padding: 22px 22px 16px;
  width: min(360px, 100%);
}

.title {
  margin: 0 0 10px;
  font-size: 17px;
  font-weight: 700;
}

.body {
  margin: 0 0 18px;
  font-size: 13.5px;
  line-height: 1.6;
  color: var(--color-text-secondary);
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

.btn {
  padding: 9px 16px;
  border-radius: 10px;
  font-size: 14px;
  font-weight: 600;
}

.btn.no {
  color: var(--color-text-secondary);
}

.btn.yes {
  background: var(--color-dark-card);
  color: #fff;
}

.btn.yes.danger {
  background: var(--color-danger);
}
</style>
