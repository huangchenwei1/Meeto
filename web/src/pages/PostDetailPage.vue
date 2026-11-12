<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { findByPostId } from '@/api/orders';
import {
  deletePost,
  fetchCandidates,
  fetchPostById,
  selectCandidate,
  signUp,
} from '@/api/posts';
import AppAvatar from '@/components/AppAvatar.vue';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { confirmDialog } from '@/utils/confirm';
import { formatDateTime, formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type { ActivityPost, Candidate } from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();

const postId = route.params.id as string;

const post = ref<ActivityPost | null>(null);
const candidates = ref<Candidate[]>([]);
const signedUp = ref(false);
const approving = ref(false);
const signingUp = ref(false);

const isMine = computed(() => post.value?.author.id === session.userId);
const isHost = computed(() => session.isHost);

let candidatePoll: number | undefined;

onMounted(async () => {
  try {
    post.value = await fetchPostById(postId);
    signedUp.value = post.value.hasApplied;
  } catch {
    showToast(strings.errorNetwork);
    return;
  }
  if (isMine.value) {
    // The candidate pool is live: the poster screens plans as they come in.
    const poll = async () => {
      try {
        candidates.value = await fetchCandidates(postId);
      } catch {
        // Transient poll failure; the next tick retries.
      }
    };
    void poll();
    candidatePoll = window.setInterval(() => void poll(), 1500);
  }
});

onUnmounted(() => window.clearInterval(candidatePoll));

/**
 * One-tap sign-up: the template fixed the place and the post fixed the
 * time, so joining the candidate pool carries nothing. Selection by the
 * poster confirms that plan in the same gesture.
 */
async function submitSignup(): Promise<void> {
  if (signingUp.value) return;
  signingUp.value = true;
  signedUp.value = true;
  try {
    post.value = await signUp(postId);
    showToast(strings.candidateSignedUpSnack);
  } catch {
    signedUp.value = false;
    showToast(strings.errorGeneric);
  } finally {
    signingUp.value = false;
  }
}

/**
 * Selection and payment are one gesture: approving a candidate creates
 * the escrow order and the payment page opens on the spot.
 */
async function approve(candidate: Candidate): Promise<void> {
  if (approving.value) return;
  approving.value = true;
  try {
    await selectCandidate(postId, candidate.applicationId);
    const order = await findByPostId(postId);
    if (
      order &&
      order.payer.id === session.userId &&
      order.status === 'AWAITING_PAYMENT'
    ) {
      await router.push(`/orders/${order.id}/pay`);
      return;
    }
    showToast(strings.paymentLaterSnack);
  } catch {
    showToast(strings.errorGeneric);
  } finally {
    approving.value = false;
  }
}

async function onDelete(): Promise<void> {
  const confirmed = await confirmDialog({
    title: strings.deletePostConfirmTitle,
    body: strings.deletePostConfirmBody,
    yesLabel: strings.deletePostYes,
    noLabel: strings.deletePostNo,
    danger: true,
  });
  if (!confirmed) return;
  try {
    await deletePost(postId);
    showToast(strings.deletePostDone);
    router.back();
  } catch {
    showToast(strings.errorGeneric);
  }
}

</script>

<template>
  <div class="detail-page">
    <PageHeader>
      <template #trailing>
        <button v-if="isMine" class="more-btn" @click="onDelete">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="var(--color-danger)" stroke-width="1.8" stroke-linecap="round">
            <path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3" />
          </svg>
        </button>
      </template>
    </PageHeader>

    <div v-if="!post" class="loading">…</div>

    <template v-else>
      <div class="content">
        <p class="scene">{{ strings.sceneLabel(post.sceneTag) }}</p>
        <h1 class="title">{{ post.title }}</h1>

        <RouterLink
          v-if="!isMine"
          class="author-row"
          :to="`/users/${post.author.id}`"
        >
          <AppAvatar :url="post.author.avatarUrl" :name="post.author.name" :size="40" />
          <div class="author-text">
            <span class="author-name">
              {{ strings.postAuthorLine(post.author.name) }}
            </span>
            <span v-if="post.author.meta" class="author-meta">{{ post.author.meta }}</span>
          </div>
        </RouterLink>

        <!-- The whole plan is already fixed: template meeting point plus
             the publisher's picked time. What you see is what happens. -->
        <div class="info-panel">
          <div v-if="post.scheduledAt" class="info-row">
            <span class="info-label">{{ strings.detailTimeLabel }}</span>
            <span class="info-value">{{ formatDateTime(post.scheduledAt) }}</span>
          </div>
          <div v-if="post.meetingPoint" class="info-row">
            <span class="info-label">{{ strings.meetingPointLabel }}</span>
            <span class="info-value">{{ post.meetingPoint }}</span>
          </div>
          <div v-if="post.area" class="info-row">
            <span class="info-label">{{ strings.detailAreaLabel }}</span>
            <span class="info-value">{{ post.area }}</span>
          </div>
          <div v-if="post.durationLabel" class="info-row">
            <span class="info-label">{{ strings.detailDurationLabel }}</span>
            <span class="info-value">{{ post.durationLabel }}</span>
          </div>
          <div class="info-row">
            <span class="info-label">{{ strings.expenseLabel }}</span>
            <span class="info-value">
              {{
                post.expensePolicy === 'TREAT'
                  ? strings.expenseTreat
                  : strings.expenseAA
              }}
            </span>
          </div>
        </div>

        <p class="detail-text">{{ post.detail }}</p>

        <!-- Owner: the live candidate pool; screening is the job. -->
        <section v-if="isMine" class="card">
          <div class="card-head">
            <span class="card-title">{{ strings.candidatesTitle }}</span>
          </div>
          <p v-if="candidates.length === 0" class="empty-note">
            {{ strings.candidatesEmpty }}
          </p>
          <div
            v-for="c in candidates"
            :key="c.author.id"
            class="candidate-row"
            @click="router.push(`/users/${c.author.id}`)"
          >
            <AppAvatar :url="c.author.avatarUrl" :name="c.author.name" :size="42" />
            <div class="candidate-main">
              <span class="candidate-name">
                {{ c.author.name }}
              </span>
              <span class="candidate-meta">{{ c.author.meta }}</span>
            </div>
            <button
              class="approve-btn"
              :disabled="approving"
              @click.stop="approve(c)"
            >
              {{ strings.approveCta }}
            </button>
          </div>
        </section>

        <!-- Owner and host candidates both see the committed budget card. -->
        <section v-if="isMine || isHost" class="card">
          <div class="budget-head">
            <span class="budget-label">{{ strings.hostingFeeLabel }}</span>
            <span class="budget-amount">{{ formatMoney(post.budgetAmount) }}</span>
          </div>
          <hr class="rule" />
          <p class="budget-rule">✓ {{ strings.budgetRuleService }}</p>
          <p class="budget-rule">
            ✓
            {{
              post.expensePolicy === 'TREAT'
                ? strings.budgetRuleExpensesTreat
                : strings.budgetRuleExpenses
            }}
          </p>
          <p class="budget-rule">✓ {{ strings.budgetRuleRelease }}</p>
        </section>

        <!-- Non-owner viewers: anonymous blurred interest. -->
        <div v-if="!isMine && post.signedCount > 0" class="signups-row">
          <div class="avatar-stack">
            <div
              v-for="(url, i) in post.applicantAvatars.slice(0, 5)"
              :key="i"
              class="blurred-avatar"
              :style="{ left: `${i * 21}px` }"
            >
              <img :src="url" alt="" />
            </div>
          </div>
          <span
            class="signups-count"
            :style="{
              marginLeft:
                post.applicantAvatars.length > 0
                  ? `${30 + 21 * (Math.min(post.applicantAvatars.length, 5) - 1) + 10}px`
                  : '0',
            }"
          >
            {{ strings.appliedCount(post.signedCount) }}
          </span>
        </div>
      </div>

      <!-- Sign-up is a host action on posts still waiting for a host;
           it is one tap, since the plan is already fixed. -->
      <footer v-if="!isMine && isHost" class="bottom-bar">
        <button
          v-if="post.status === 'OPEN'"
          class="btn-primary"
          :disabled="signedUp || signingUp"
          @click="submitSignup"
        >
          {{ signedUp ? strings.signedUpCta : strings.signUpCta }}
        </button>
        <button v-else class="btn-primary closed" disabled>
          {{
            post.status === 'COMPLETED'
              ? strings.postFinishedCta
              : strings.postTakenCta
          }}
        </button>
      </footer>
    </template>
  </div>
</template>

<style scoped>
.detail-page {
  min-height: 100dvh;
  background: var(--color-background);
  padding-bottom: 90px;
}

.loading {
  padding-top: 100px;
  text-align: center;
  color: var(--color-text-hint);
}

.content {
  padding: 4px 20px 24px;
}

.more-btn {
  width: 38px;
  height: 38px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.scene {
  margin: 0;
  font-size: 13px;
  font-weight: 600;
  color: var(--color-accent);
}

.title {
  margin: 6px 0 0;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.3;
}

.author-row {
  margin-top: 14px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.author-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.author-name {
  font-size: 14.5px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.author-meta {
  font-size: 12px;
  color: var(--color-text-hint);
}

.info-panel {
  margin-top: 16px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 4px 16px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  padding: 10px 0;
  font-size: 13.5px;
}

.info-row + .info-row {
  border-top: 1px solid var(--color-divider);
}

.info-label {
  color: var(--color-text-secondary);
}

.info-value {
  font-weight: 600;
}

.detail-text {
  margin: 16px 0 18px;
  font-size: 14.5px;
  line-height: 1.75;
  color: var(--color-text-secondary);
  white-space: pre-wrap;
}

.card {
  border: 1px solid var(--color-border);
  border-radius: 16px;
  padding: 14px 16px;
  margin-bottom: 14px;
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.card-title {
  font-size: 14px;
  font-weight: 700;
}

.card-sub {
  font-size: 12px;
  color: var(--color-text-hint);
}

.empty-note {
  margin: 10px 0 2px;
  font-size: 12.5px;
  color: var(--color-text-hint);
}

.candidate-row {
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 10px 0;
  cursor: pointer;
}

.candidate-row + .candidate-row {
  border-top: 1px solid var(--color-divider);
}

.candidate-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.candidate-name {
  font-size: 14.5px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.candidate-meta {
  font-size: 12px;
  color: var(--color-text-hint);
}

.approve-btn {
  padding: 7px 16px;
  border-radius: 10px;
  background: var(--color-text-primary);
  color: #fff;
  font-size: 12.5px;
  font-weight: 700;
  flex-shrink: 0;
}

.budget-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.budget-label {
  font-size: 13px;
  color: var(--color-text-secondary);
}

.budget-amount {
  font-size: 20px;
  font-weight: 800;
}

.rule {
  border: none;
  border-top: 1px solid var(--color-divider);
  margin: 10px 0;
}

.budget-rule {
  margin: 6px 0 0;
  font-size: 12.5px;
  line-height: 1.6;
  color: var(--color-text-secondary);
}

.signups-row {
  display: flex;
  align-items: center;
  position: relative;
  height: 30px;
}

.avatar-stack {
  position: absolute;
  left: 0;
  top: 0;
  height: 30px;
}

.blurred-avatar {
  position: absolute;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  border: 2px solid var(--color-background);
  overflow: hidden;
}

.blurred-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: blur(4px);
}

.signups-count {
  font-size: 13px;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.bottom-bar {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  padding: 14px 20px calc(14px + env(safe-area-inset-bottom));
  background: var(--color-background);
  border-top: 1px solid var(--color-divider);
  z-index: 40;
}

.btn-primary.closed {
  background: var(--color-surface);
  color: var(--color-text-hint);
}
</style>
