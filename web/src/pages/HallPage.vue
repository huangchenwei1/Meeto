<script setup lang="ts">
import { computed, onActivated, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import {
  fetchOpenRequests,
  fetchSignupNotices,
  fetchTemplates,
} from '@/api/posts';
import { fetchProposals } from '@/api/proposals';
import { proposalCoverUrl } from '@/api/mappers';
import FeedActivityCard from '@/components/FeedActivityCard.vue';
import GuidelinesBanner from '@/components/GuidelinesBanner.vue';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { formatDateTime, formatMoney } from '@/utils/format';
import type {
  ActivityPost,
  ActivityTemplate,
  ProposalCard,
  SignupNotice,
} from '@/types/models';

const router = useRouter();
const session = useSessionStore();

const requests = ref<ActivityPost[]>([]);
const proposals = ref<ProposalCard[]>([]);
const templates = ref<ActivityTemplate[]>([]);
const loaded = ref(false);

const isHost = computed(() => session.isHost);

// WeChat-Moments-style sign-up notice: the server lists every pending
// sign-up on my open posts/pitches; we diff against a locally stored
// last-seen timestamp so only fresh ones front the pill. Tapping jumps
// to the newest sign-up's surface (the candidate pool lives there) and
// marks everything seen.
const SEEN_KEY_PREFIX = 'meeto.signupSeenAt.';
const notices = ref<SignupNotice[]>([]);
const seenAt = ref(0);

function seenKey(): string {
  return `${SEEN_KEY_PREFIX}${session.userId}`;
}

const unreadNotices = computed(() =>
  notices.value.filter((n) => n.createdAt.getTime() > seenAt.value),
);

function openNotices(): void {
  const newest = unreadNotices.value[0];
  if (!newest) return;
  seenAt.value = Date.now();
  window.localStorage.setItem(seenKey(), String(seenAt.value));
  const path =
    newest.kind === 'APPLICATION'
      ? `/posts/${newest.targetId}`
      : `/proposals/${newest.targetId}`;
  void router.push(path);
}

type FeedItem =
  | { kind: 'request'; post: ActivityPost }
  | { kind: 'proposal'; proposal: ProposalCard };

/**
 * The merged feed: cards the caller can act on come first (hosts work
 * the requests, users shop the proposals), newest first within each
 * group.
 */
const items = computed<FeedItem[]>(() => {
  const list: FeedItem[] = [
    ...requests.value.map((post) => ({ kind: 'request', post }) as FeedItem),
    ...proposals.value.map(
      (proposal) => ({ kind: 'proposal', proposal }) as FeedItem,
    ),
  ];
  const group = (item: FeedItem) => {
    const actionable = isHost.value
      ? item.kind === 'request'
      : item.kind === 'proposal';
    return actionable ? 0 : 1;
  };
  const createdAt = (item: FeedItem) =>
    item.kind === 'request'
      ? item.post.createdAt.getTime()
      : item.proposal.createdAt.getTime();
  return list.sort((a, b) => {
    const byGroup = group(a) - group(b);
    return byGroup !== 0 ? byGroup : createdAt(b) - createdAt(a);
  });
});

async function load(): Promise<void> {
  try {
    const [r, p, n] = await Promise.all([
      fetchOpenRequests(),
      fetchProposals(),
      fetchSignupNotices(),
    ]);
    requests.value = r;
    proposals.value = p;
    notices.value = n;
    loaded.value = true;
  } catch {
    // Keep the last known list; the next poll retries.
  }
}

let pollTimer: number | undefined;

onMounted(() => {
  seenAt.value = Number(window.localStorage.getItem(seenKey()) ?? 0);
  void load();
  // Static operations content: one fetch is enough, no polling.
  void fetchTemplates().then((list) => {
    templates.value = list;
  });
  pollTimer = window.setInterval(() => void load(), 5000);
});

onActivated(() => void load());

onUnmounted(() => window.clearInterval(pollTimer));

function requestInfoLine(post: ActivityPost): string {
  return [
    post.scheduledAt ? formatDateTime(post.scheduledAt) : '',
    post.area,
    post.signedCount > 0 ? strings.appliedCount(post.signedCount) : '',
  ]
    .filter((s) => s.length > 0)
    .join(' · ');
}

function proposalInfoLine(p: ProposalCard): string {
  const location = [p.hostCity, p.area].filter((s) => s.length > 0).join(' · ');
  return [
    strings.proposalTimeSlotName(p.timeSlot),
    location,
    p.inviteCount > 0 ? strings.proposalInviteCount(p.inviteCount) : '',
  ]
    .filter((s) => s.length > 0)
    .join(' · ');
}

function hostMetaLine(p: ProposalCard): string {
  const record =
    p.hostCompletedActivities > 0
      ? strings.hostCompletedLabel(p.hostCompletedActivities)
      : strings.hostNewLabel;
  return p.hostMeta.length === 0 ? record : `${p.hostMeta} · ${record}`;
}
</script>

<template>
  <div class="hall-page">
    <header class="hall-header">
      <h1 class="page-title">{{ strings.hallTitle }}</h1>
      <button
        class="publish-btn"
        aria-label="publish"
        @click="router.push('/publish')"
      >
        <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="3" width="18" height="18" rx="5" />
          <path d="M12 8v8M8 12h8" />
        </svg>
      </button>
    </header>

    <GuidelinesBanner />

    <!-- Curated shelf: picking a template prefills the composer, so
         posting is "choose and confirm" instead of a blank form. -->
    <section v-if="templates.length > 0" class="shelf">
      <h2 class="shelf-title">{{ strings.hotActivitiesTab }}</h2>
      <div class="shelf-scroll">
        <article
          v-for="t in templates"
          :key="t.id"
          class="template-card"
          @click="router.push(`/publish?template=${t.id}`)"
        >
          <img class="template-cover" :src="t.imageUrl" alt="" />
          <div class="template-text">
            <p class="template-title">{{ t.title }}</p>
            <p class="template-desc">{{ t.description }}</p>
            <p class="template-meta">
              <span class="template-scene">{{ strings.sceneLabel(t.sceneTag) }}</span>
              <template v-if="t.area"> · {{ t.area }}</template>
            </p>
          </div>
          <span class="template-launch">{{ strings.templateLaunchCta }}</span>
        </article>
      </div>
    </section>

    <!-- Moments-style unread notice: newest sign-up's avatar + count,
         fronting the stream it belongs to; tapping opens that sign-up's
         surface and marks everything seen. -->
    <div v-if="unreadNotices.length > 0" class="notice-row">
      <button class="notice-pill" @click="openNotices">
        <img
          v-if="unreadNotices[0].actor.avatarUrl"
          class="notice-avatar"
          :src="unreadNotices[0].actor.avatarUrl"
          alt=""
        />
        <span class="notice-text">
          {{ strings.signupNoticePill(unreadNotices.length) }}
        </span>
      </button>
    </div>

    <div v-if="!loaded" class="loading">…</div>

    <div v-else-if="items.length === 0" class="empty">
      {{ strings.hallEmpty }}
    </div>

    <div v-else class="feed">
      <template v-for="item in items">
        <FeedActivityCard
          v-if="item.kind === 'request'"
          :key="`r-${item.post.id}`"
          :avatar-url="item.post.author.avatarUrl"
          :author-name="item.post.author.name"
          :author-verified="item.post.author.isVerified"
          :meta-line="item.post.author.meta"
          :created-at="item.post.createdAt"
          :image-url="item.post.imageUrl"
          :scene-label="strings.sceneLabel(item.post.sceneTag)"
          :title="item.post.title"
          :description="item.post.description"
          :info-text="requestInfoLine(item.post)"
          :footer-text="
            item.post.expensePolicy === 'TREAT'
              ? `${formatMoney(item.post.budgetAmount)} · ${strings.expenseTreat}`
              : formatMoney(item.post.budgetAmount)
          "
          @tap="router.push(`/posts/${item.post.id}`)"
        >
          <template #action>
            <template v-if="isHost">
              <span v-if="item.post.hasApplied" class="applied-badge">
                {{ strings.gigAppliedBadge }}
              </span>
              <span v-else class="action-pill">{{ strings.gigPitchCta }}</span>
            </template>
          </template>
        </FeedActivityCard>

        <FeedActivityCard
          v-else
          :key="`p-${item.proposal.id}`"
          :avatar-url="item.proposal.hostAvatarUrl"
          :author-name="item.proposal.hostName"
          :author-verified="item.proposal.hostIsVerified"
          :meta-line="hostMetaLine(item.proposal)"
          :created-at="item.proposal.createdAt"
          :image-url="proposalCoverUrl(item.proposal)"
          :scene-label="strings.sceneLabel(item.proposal.sceneTag)"
          :title="item.proposal.title"
          :description="item.proposal.description"
          :info-text="proposalInfoLine(item.proposal)"
          @tap="router.push(`/proposals/${item.proposal.id}`)"
        >
          <template #action>
            <template v-if="!isHost">
              <span v-if="item.proposal.hasInvited" class="applied-badge">
                {{ strings.invitedBadge }}
              </span>
              <span v-else class="action-pill">{{ strings.hostInviteCta }}</span>
            </template>
          </template>
        </FeedActivityCard>
      </template>
    </div>
  </div>
</template>

<style scoped>
.hall-page {
  padding-bottom: 24px;
}

.hall-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 12px 10px 20px;
}

.hall-header .page-title {
  font-size: 20px;
}

.publish-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-primary);
}

.notice-row {
  display: flex;
  justify-content: center;
  padding: 6px 0 2px;
}

.notice-pill {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px;
  border-radius: 10px;
  background: var(--color-dark-card);
}

.notice-avatar {
  width: 30px;
  height: 30px;
  border-radius: 6px;
  object-fit: cover;
}

.notice-text {
  padding-right: 8px;
  font-size: 14px;
  font-weight: 700;
  color: #fff;
}

.shelf {
  padding: 8px 0 4px;
}

.shelf-title {
  margin: 0 0 8px;
  padding: 0 20px;
  font-size: 15px;
  font-weight: 800;
}

.shelf-scroll {
  display: flex;
  gap: 10px;
  overflow-x: auto;
  padding: 0 16px 10px;
  scrollbar-width: none;
}

.shelf-scroll::-webkit-scrollbar {
  display: none;
}

.template-card {
  flex-shrink: 0;
  width: 280px;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  cursor: pointer;
}

.template-cover {
  width: 56px;
  height: 56px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
  background: var(--color-surface);
}

.template-text {
  flex: 1;
  min-width: 0;
}

.template-title {
  margin: 0;
  font-size: 13.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.template-desc {
  margin: 3px 0 0;
  font-size: 11.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.template-meta {
  margin: 5px 0 0;
  font-size: 11.5px;
  color: var(--color-text-hint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.template-scene {
  color: var(--color-accent);
  font-weight: 600;
}

.template-launch {
  flex-shrink: 0;
  padding: 6px 13px;
  border-radius: 999px;
  background: var(--color-button-soft);
  font-size: 12px;
  font-weight: 700;
}

.loading,
.empty {
  padding-top: 100px;
  text-align: center;
  color: var(--color-text-hint);
  font-size: 14px;
}

.feed {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 10px 16px 24px;
}

.action-pill {
  display: inline-flex;
  padding: 8px 18px;
  border-radius: 999px;
  background: var(--color-dark-card);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
}

.applied-badge {
  display: inline-flex;
  padding: 7px 14px;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  color: var(--color-text-hint);
  font-size: 12.5px;
  font-weight: 600;
}
</style>
