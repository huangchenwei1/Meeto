<script setup lang="ts">
import { onActivated, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { fetchCurrentUser, fetchWallet } from '@/api/users';
import AppAvatar from '@/components/AppAvatar.vue';
import { INTRO_SEEN_KEY } from '@/constants/guest';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { formatMoney } from '@/utils/format';
import type { CurrentUser, WalletSummary } from '@/types/models';

const router = useRouter();
const session = useSessionStore();

const user = ref<CurrentUser | null>(null);
const wallet = ref<WalletSummary | null>(null);

/** Re-fetches profile and wallet so settled earnings show up on return. */
async function load(): Promise<void> {
  const [u, w] = await Promise.all([fetchCurrentUser(), fetchWallet()]);
  user.value = u;
  wallet.value = w;
}

onMounted(() => void load());
onActivated(() => void load());

function logout(): void {
  session.clear();
  sessionStorage.removeItem(INTRO_SEEN_KEY);
  void router.replace('/');
}
</script>

<template>
  <div class="me-page">
    <header class="page-head">
      <h1 class="page-title">{{ strings.tabMe }}</h1>
    </header>

    <div v-if="!user || !wallet" class="loading">…</div>

    <template v-else>
      <section class="profile-card">
        <AppAvatar :size="64" :url="user.avatarUrl" :name="user.name" />
        <div class="profile-text">
          <div class="name-row">
            <span class="name">{{ user.name }}</span>
          </div>
          <p class="id-line">{{ user.idLine }}</p>
        </div>
        <button
          class="edit-btn"
          aria-label="edit profile"
          @click="router.push('/setup?mode=edit')"
        >
          ✎
        </button>
      </section>

      <section class="stats-row">
        <div v-for="stat in user.stats" :key="stat.label" class="stat">
          <span class="stat-value">{{ stat.value }}</span>
          <span class="stat-label">{{ stat.label }}</span>
        </div>
      </section>

      <!-- Only hosts earn, so only the host side gets a wallet. -->
      <section
        v-if="session.isHost"
        class="wallet-card"
        @click="router.push('/wallet')"
      >
        <p class="wallet-label">{{ strings.walletLabel }}</p>
        <p class="wallet-amount">{{ formatMoney(wallet.monthIncome) }}</p>
        <div class="wallet-foot">
          <span class="wallet-sub">
            {{ strings.walletWithdrawable(formatMoney(wallet.withdrawable)) }}
          </span>
          <button class="withdraw-btn" @click.stop="router.push('/wallet')">
            {{ strings.withdraw }}
          </button>
        </div>
      </section>

      <nav class="menu">
        <button class="menu-item" @click="router.push('/my-posts')">
          <span class="menu-icon">📝</span>
          <span class="menu-label">{{ strings.menuMyPosts }}</span>
          <span class="menu-arrow">›</span>
        </button>
        <button class="menu-item" @click="router.push('/guidelines')">
          <span class="menu-icon">📖</span>
          <span class="menu-label">{{ strings.guidelinesTitle }}</span>
          <span class="menu-arrow">›</span>
        </button>
        <button class="menu-item danger" @click="logout">
          <span class="menu-icon">⏻</span>
          <span class="menu-label">{{ strings.menuLogout }}</span>
        </button>
      </nav>
    </template>
  </div>
</template>

<style scoped>
.me-page {
  min-height: calc(100dvh - 64px);
  background: var(--color-background);
  padding-bottom: 24px;
}

.page-head {
  padding: 14px 20px 10px;
}

.page-head .page-title {
  font-size: 20px;
}

.loading {
  padding: 80px 0 0;
  text-align: center;
  color: var(--color-text-secondary);
}

.profile-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px 16px 0;
}

.profile-text {
  flex: 1;
  min-width: 0;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 8px;
}

.name {
  font-size: 18px;
  font-weight: 800;
}

.id-line {
  margin: 4px 0 0;
  font-size: 12.5px;
  color: var(--color-text-hint);
}

.edit-btn {
  font-size: 18px;
  color: var(--color-text-secondary);
  padding: 8px;
}

.stats-row {
  display: flex;
  margin: 16px 16px 0;
  padding: 14px 0;
  border: 1px solid var(--color-border);
  border-radius: 16px;
}

.stat {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
}

.stat-value {
  font-size: 17px;
  font-weight: 800;
}

.stat-label {
  font-size: 11.5px;
  color: var(--color-text-hint);
}

.wallet-card {
  margin: 16px 16px 8px;
  padding: 18px;
  background: var(--color-dark-card);
  border-radius: 18px;
  cursor: pointer;
}

.wallet-label {
  margin: 0;
  font-size: 12.5px;
  color: var(--color-on-dark-secondary);
}

.wallet-amount {
  margin: 10px 0;
  font-size: 30px;
  font-weight: 800;
  color: #fff;
}

.wallet-foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.wallet-sub {
  font-size: 11.5px;
  color: var(--color-on-dark-secondary);
}

.withdraw-btn {
  padding: 8px 18px;
  border-radius: 999px;
  background: #fff;
  color: var(--color-text-primary);
  font-size: 12.5px;
  font-weight: 700;
  flex-shrink: 0;
}

.menu {
  margin-top: 8px;
}

.menu-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 15px 20px;
  font-size: 14.5px;
  text-align: left;
}

.menu-icon {
  width: 24px;
  text-align: center;
}

.menu-label {
  flex: 1;
}

.menu-hint {
  font-size: 12px;
  color: var(--color-text-hint);
}

.menu-arrow {
  color: var(--color-text-hint);
  font-size: 17px;
}

.menu-item.danger {
  color: #ef4444;
}
</style>
