<script setup lang="ts">
import { computed, onActivated, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { listMine } from '@/api/orders';
import { fetchAppliedRequests, fetchPostsByAuthor } from '@/api/posts';
import { fetchProposals } from '@/api/proposals';
import { proposalCoverUrl } from '@/api/mappers';
import { strings } from '@/constants/strings';
import { actionableCount } from '@/stores/badge';
import { useSessionStore } from '@/stores/session';
import { formatDateTime, formatMoney } from '@/utils/format';
import type { ActivityPost, LiveOrder, ProposalCard } from '@/types/models';

const router = useRouter();
const session = useSessionStore();

/**
 * One entry on the board. group drives the sort: running deals first,
 * then everything still waiting, finished deals last.
 */
type Journey =
  | { kind: 'order'; order: LiveOrder; group: number; createdAt: Date }
  | { kind: 'post'; post: ActivityPost; mine: boolean; group: number; createdAt: Date }
  | { kind: 'proposal'; proposal: ProposalCard; group: number; createdAt: Date };

const journeys = ref<Journey[]>([]);
const loaded = ref(false);

let pollTimer: number | undefined;

async function poll(): Promise<void> {
  const myId = session.userId;
  const isHost = session.isHost;
  try {
    const [orders, myPosts, proposals, applied] = await Promise.all([
      listMine(true),
      isHost ? Promise.resolve([] as ActivityPost[]) : fetchPostsByAuthor(myId),
      isHost ? fetchProposals() : Promise.resolve([] as ProposalCard[]),
      isHost ? fetchAppliedRequests() : Promise.resolve([] as ActivityPost[]),
    ]);
    const list: Journey[] = [
      // Running and finished deals, plus deals waiting on MY payment
      // (e.g. a host picked my invitation): those need a way in to pay.
      // Cancelled orders and deals unpaid by the counterpart stay off.
      ...orders
        .filter(
          (o) =>
            o.status === 'ACTIVE' ||
            o.status === 'COMPLETED' ||
            (o.status === 'AWAITING_PAYMENT' && o.payer.id === myId),
        )
        .map(
          (order): Journey => ({
            kind: 'order',
            order,
            group: order.status === 'COMPLETED' ? 2 : 0,
            createdAt: order.createdAt,
          }),
        ),
      // My open posts, waiting for signups.
      ...myPosts
        .filter((p) => p.type !== 'MOMENT' && p.status === 'OPEN')
        .map(
          (post): Journey => ({
            kind: 'post',
            post,
            mine: true,
            group: 1,
            createdAt: post.createdAt,
          }),
        ),
      // My open pitches with their invite queues (hosts).
      ...proposals
        .filter((p) => p.hostId === myId && p.status === 'OPEN')
        .map(
          (proposal): Journey => ({
            kind: 'proposal',
            proposal,
            group: 1,
            createdAt: proposal.createdAt,
          }),
        ),
      // Posts I signed up for, waiting for the poster to pick (hosts).
      ...applied.map(
        (post): Journey => ({
          kind: 'post',
          post,
          mine: false,
          group: 1,
          createdAt: post.createdAt,
        }),
      ),
    ];
    list.sort((a, b) =>
      a.group !== b.group
        ? a.group - b.group
        : b.createdAt.getTime() - a.createdAt.getTime(),
    );
    journeys.value = list;
    loaded.value = true;
    // Counterpart interactions waiting on me drive the tab badge. Count
    // PEOPLE, not boards: the hall's sign-up pill and the cards both say
    // "N 人已报名", so the badge must add up the same way.
    actionableCount.value = list.reduce(
      (sum, j) =>
        sum +
        (j.kind === 'post' && j.mine
          ? j.post.signedCount
          : j.kind === 'proposal'
            ? j.proposal.inviteCount
            : 0),
      0,
    );
  } catch {
    // Keep the last known board; the next poll retries.
  }
}

onMounted(() => {
  void poll();
  pollTimer = window.setInterval(() => void poll(), 3000);
});

onActivated(() => void poll());

onUnmounted(() => window.clearInterval(pollTimer));

const visible = computed(() => journeys.value);

function openJourney(j: Journey): void {
  if (j.kind === 'order') {
    // An unpaid order routes to checkout, not the chat room.
    void router.push(
      j.order.status === 'AWAITING_PAYMENT'
        ? `/orders/${j.order.id}/pay`
        : `/orders/${j.order.id}`,
    );
  } else if (j.kind === 'post') {
    void router.push(`/posts/${j.post.id}`);
  } else {
    void router.push(`/proposals/${j.proposal.id}`);
  }
}

function orderStatusLabel(order: LiveOrder): string {
  if (order.status === 'AWAITING_PAYMENT') return strings.statusAwaitingPayment;
  return order.status === 'ACTIVE'
    ? strings.statusActive
    : strings.statusCompleted;
}

function orderCtaLabel(order: LiveOrder): string {
  if (order.status === 'AWAITING_PAYMENT') return strings.myOrderPayCta;
  return order.status === 'ACTIVE'
    ? strings.myOrderChatCta
    : strings.myOrderDetailCta;
}

/**
 * Minute-level remaining time for a running service; the 3s poll keeps
 * it fresh enough without a dedicated ticker on the board.
 */
function orderRunningLine(order: LiveOrder): string {
  if (
    order.status !== 'ACTIVE' ||
    !order.startedAt ||
    order.planDurationMinutes <= 0
  ) {
    return '';
  }
  const remainingMs =
    order.startedAt.getTime() +
    order.planDurationMinutes * 60000 -
    Date.now();
  if (remainingMs <= 0) return strings.settlingNote;
  return strings.serviceRemainingNote(
    strings.remainingShortLabel(Math.ceil(remainingMs / 60000)),
  );
}

function orderWhenLine(order: LiveOrder): string {
  if (!order.planAt) return '';
  const when = formatDateTime(order.planAt);
  return order.planDurationMinutes > 0
    ? `${when} · ${strings.durationAbout(order.planDurationMinutes)}`
    : when;
}

/** The merchant line: the one providing or ordering the service. */
function providerLine(order: LiveOrder): string {
  const peer = order.payer.id === session.userId ? order.earner : order.payer;
  return order.payer.id === session.userId
    ? strings.myOrderHostLine(peer.name)
    : strings.myOrderGuestLine(peer.name);
}

function postInfoLine(post: ActivityPost): string {
  return [
    strings.sceneLabel(post.sceneTag),
    post.scheduledAt ? formatDateTime(post.scheduledAt) : '',
    post.area,
  ]
    .filter((s) => s.length > 0)
    .join(' · ');
}

function proposalInfoLine(p: ProposalCard): string {
  return [
    strings.sceneLabel(p.sceneTag),
    strings.proposalTimeSlotName(p.timeSlot),
    p.area,
  ]
    .filter((s) => s.length > 0)
    .join(' · ');
}
</script>

<template>
  <div class="activities-page">
    <header class="page-head">
      <h1 class="page-title">{{ strings.tabMyActivities }}</h1>
    </header>

    <div v-if="!loaded" class="loading">…</div>

    <div v-else-if="visible.length === 0" class="empty">
      {{ strings.myActivitiesEmpty }}
    </div>

    <div v-else class="board">
      <template v-for="j in visible">
        <!-- A formed deal as a service-purchase card. -->
        <article
          v-if="j.kind === 'order'"
          :key="`o-${j.order.id}`"
          class="big-card"
          @click="openJourney(j)"
        >
          <div class="card-main">
            <img
              v-if="j.order.postImageUrl"
              class="cover"
              :src="j.order.postImageUrl"
              alt=""
            />
            <div v-else class="cover-fallback">📅</div>
            <div class="card-text">
              <p class="card-title">{{ j.order.postTitle }}</p>
              <p class="card-line">{{ providerLine(j.order) }}</p>
              <p v-if="j.order.planPlace" class="card-line">{{ j.order.planPlace }}</p>
              <p v-if="orderWhenLine(j.order)" class="card-line">
                {{ orderWhenLine(j.order) }}
              </p>
              <p v-if="orderRunningLine(j.order)" class="card-line running">
                {{ orderRunningLine(j.order) }}
              </p>
            </div>
            <span
              class="status"
              :class="j.order.status === 'COMPLETED' ? 'muted' : 'accent'"
            >
              {{ orderStatusLabel(j.order) }}
            </span>
          </div>
          <div class="card-footer">
            <span class="footer-left">
              {{ strings.myOrderCreatedAt(formatDateTime(j.order.createdAt)) }}
            </span>
            <span class="footer-total">
              {{ strings.myOrderTotal('') }}
              <strong>{{ formatMoney(j.order.feeAmount) }}</strong>
            </span>
          </div>
          <div class="card-actions">
            <button
              class="pill"
              :class="{ accent: j.order.status !== 'COMPLETED' }"
              @click.stop="openJourney(j)"
            >
              {{ orderCtaLabel(j.order) }}
            </button>
          </div>
        </article>

        <!-- A journey still waiting on the market. -->
        <article
          v-else-if="j.kind === 'post'"
          :key="`p-${j.post.id}`"
          class="big-card"
          @click="openJourney(j)"
        >
          <div class="card-main">
            <img v-if="j.post.imageUrl" class="cover" :src="j.post.imageUrl" alt="" />
            <div v-else class="cover-fallback">{{ j.mine ? '📅' : '✉️' }}</div>
            <div class="card-text">
              <p class="card-title">{{ j.post.title }}</p>
              <p class="card-line">{{ postInfoLine(j.post) }}</p>
            </div>
            <span
              v-if="j.mine && j.post.signedCount > 0"
              class="status accent"
            >
              {{ strings.appliedCount(j.post.signedCount) }}
            </span>
          </div>
          <div class="card-footer">
            <span class="footer-left">
              {{ strings.activityPostedAt(formatDateTime(j.post.createdAt)) }}
            </span>
          </div>
        </article>

        <article
          v-else
          :key="`pr-${j.proposal.id}`"
          class="big-card"
          @click="openJourney(j)"
        >
          <div class="card-main">
            <img class="cover" :src="proposalCoverUrl(j.proposal)" alt="" />
            <div class="card-text">
              <p class="card-title">{{ j.proposal.title }}</p>
              <p class="card-line">{{ proposalInfoLine(j.proposal) }}</p>
            </div>
            <span v-if="j.proposal.inviteCount > 0" class="status accent">
              {{ strings.activityInvites(j.proposal.inviteCount) }}
            </span>
          </div>
          <div class="card-footer">
            <span class="footer-left">
              {{ strings.activityPostedAt(formatDateTime(j.proposal.createdAt)) }}
            </span>
          </div>
        </article>
      </template>
    </div>
  </div>
</template>

<style scoped>
.activities-page {
  min-height: calc(100dvh - 64px);
  background: var(--color-surface);
  padding-bottom: 20px;
}

.page-head {
  padding: 14px 20px 10px;
}

.page-head .page-title {
  font-size: 20px;
}

.loading,
.empty {
  padding: 80px 32px 0;
  text-align: center;
  color: var(--color-text-secondary);
  font-size: 15px;
}

.board {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 0 12px 20px;
}

.big-card {
  background: var(--color-background);
  border-radius: 14px;
  padding: 12px 14px;
  cursor: pointer;
}

.card-main {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}

.cover {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  object-fit: cover;
  flex-shrink: 0;
}

.cover-fallback {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  background: var(--color-accent-soft);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 20px;
  flex-shrink: 0;
}

.card-text {
  flex: 1;
  min-width: 0;
}

.card-title {
  margin: 0;
  font-size: 14.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-line {
  margin: 3px 0 0;
  font-size: 12.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.card-line.running {
  color: var(--color-accent);
  font-weight: 600;
}

.status {
  font-size: 12.5px;
  font-weight: 600;
  flex-shrink: 0;
}

.status.accent {
  color: var(--color-accent);
}

.status.muted {
  color: var(--color-text-hint);
}

.card-footer {
  margin-top: 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.footer-left {
  font-size: 11.5px;
  color: var(--color-text-hint);
}

.footer-total {
  font-size: 12.5px;
  color: var(--color-text-secondary);
}

.footer-total strong {
  font-size: 15px;
  font-weight: 800;
  color: var(--color-text-primary);
}

.card-actions {
  margin-top: 10px;
  display: flex;
  justify-content: flex-end;
}

.pill {
  padding: 7px 16px;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  color: var(--color-text-secondary);
  font-size: 12.5px;
  font-weight: 600;
  background: transparent;
}

.pill.accent {
  background: var(--color-accent);
  border-color: var(--color-accent);
  color: #fff;
}
</style>
