<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';

import { fetchUserDetail } from '@/api/users';
import AppAvatar from '@/components/AppAvatar.vue';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import type { UserDetail } from '@/types/models';

const route = useRoute();

const user = ref<UserDetail | null>(null);
const loading = ref(true);

onMounted(async () => {
  user.value = await fetchUserDetail(route.params.id as string);
  loading.value = false;
});

const metaLine = computed(() =>
  user.value
    ? [user.value.meta, user.value.city, user.value.joinedText]
        .filter((part) => part.length > 0)
        .join(' · ')
    : '',
);

/**
 * Bumble-style weave: content cards (about, basics, interests) alternate
 * with full-width photo cards; leftover photos stack below. Stats close
 * the page.
 */
type Block =
  | { kind: 'about' }
  | { kind: 'basics' }
  | { kind: 'interests' }
  | { kind: 'photo'; url: string };

const blocks = computed<Block[]>(() => {
  const u = user.value;
  if (!u) return [];
  const photos = u.photos.filter((p) => p !== u.avatarUrl);
  const content: Block[] = [];
  if (u.bio.length > 0) content.push({ kind: 'about' });
  if (u.info.length > 0) content.push({ kind: 'basics' });
  if (u.tags.length > 0) content.push({ kind: 'interests' });

  const woven: Block[] = [];
  let photoIndex = 0;
  for (const card of content) {
    woven.push(card);
    if (photoIndex < photos.length) {
      woven.push({ kind: 'photo', url: photos[photoIndex] });
      photoIndex += 1;
    }
  }
  for (; photoIndex < photos.length; photoIndex += 1) {
    woven.push({ kind: 'photo', url: photos[photoIndex] });
  }
  return woven;
});

const BASIC_ICONS: Record<string, string> = {
  [strings.profileJobLabel]: '💼',
  [strings.profileEducationLabel]: '🎓',
  [strings.profileHeightLabel]: '📏',
  [strings.profileWeightLabel]: '⚖️',
  [strings.profileLivesInLabel]: '📍',
};
</script>

<template>
  <div class="user-page">
    <PageHeader :title="strings.profileTitle" />

    <div v-if="loading" class="loading">…</div>

    <div v-else-if="user" class="content">
      <!-- Identity header: avatar, name, badge, meta line. -->
      <section class="card header-card">
        <AppAvatar :size="76" :url="user.avatarUrl" :name="user.name" />
        <div class="name-row">
          <span class="name">{{ user.name }}</span>
        </div>
        <p class="meta-line">{{ metaLine }}</p>
      </section>

      <template v-for="(block, index) in blocks" :key="index">
        <section v-if="block.kind === 'about'" class="card">
          <h3 class="card-title">{{ strings.profileAboutTitle }}</h3>
          <p class="bio">{{ user.bio }}</p>
        </section>

        <section v-else-if="block.kind === 'basics'" class="card">
          <h3 class="card-title">{{ strings.profileBasicsTitle }}</h3>
          <div class="chip-wrap">
            <span v-for="item in user.info" :key="item.label" class="basic-chip">
              <span>{{ BASIC_ICONS[item.label] ?? 'ℹ️' }}</span>
              <span>{{ item.value }}</span>
            </span>
          </div>
        </section>

        <section v-else-if="block.kind === 'interests'" class="card">
          <h3 class="card-title">{{ strings.profileInterestsTitle }}</h3>
          <div class="chip-wrap">
            <span v-for="tag in user.tags" :key="tag" class="interest-chip">
              {{ tag }}
            </span>
          </div>
        </section>

        <img v-else class="photo-card" :src="block.url" alt="" />
      </template>

      <!-- The trust assets a hosting marketplace has: activity stats. -->
      <section class="card stats-card">
        <div v-for="stat in user.stats" :key="stat.label" class="stat">
          <span class="stat-value">{{ stat.value }}</span>
          <span class="stat-label">{{ stat.label }}</span>
        </div>
      </section>
    </div>
  </div>
</template>

<style scoped>
.user-page {
  min-height: 100dvh;
  background: var(--color-surface);
}

.loading {
  padding: 80px 0 0;
  text-align: center;
  color: var(--color-text-secondary);
}

.content {
  padding: 6px 14px 30px;
}

.card {
  margin-top: 12px;
  padding: 18px;
  background: var(--color-background);
  border-radius: 20px;
}

.header-card {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.name-row {
  margin-top: 10px;
  display: flex;
  align-items: center;
  gap: 7px;
}

.name {
  font-size: 20px;
  font-weight: 800;
}

.meta-line {
  margin: 5px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
}

.card-title {
  margin: 0 0 10px;
  font-size: 12.5px;
  font-weight: 700;
  color: var(--color-text-hint);
}

.bio {
  margin: 0;
  font-size: 14.5px;
  line-height: 1.7;
}

.chip-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.basic-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 12px;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  font-size: 13px;
  font-weight: 600;
}

.interest-chip {
  padding: 7px 13px;
  background: var(--color-accent-soft);
  color: var(--color-accent);
  border-radius: 999px;
  font-size: 12.5px;
  font-weight: 600;
}

.photo-card {
  display: block;
  width: 100%;
  aspect-ratio: 4 / 5;
  object-fit: cover;
  border-radius: 20px;
  margin-top: 12px;
}

.stats-card {
  display: flex;
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
</style>
