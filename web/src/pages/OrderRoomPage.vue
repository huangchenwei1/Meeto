<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { ApiError } from '@/api/client';
import { parseActivityRequest } from '@/api/mappers';
import {
  cancel,
  getOrder,
  isCancellableNow,
  listMessages,
  peerOf,
  peerPhoneOf,
  reportOrder,
  respondActivityRequest,
  sendActivityRequest,
  sendMessage,
  start,
} from '@/api/orders';
import { fetchTemplates } from '@/api/posts';
import MeetTimePicker from '@/components/MeetTimePicker.vue';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { usePricingStore } from '@/stores/pricing';
import { useSessionStore } from '@/stores/session';
import { confirmDialog } from '@/utils/confirm';
import { formatDateTime, formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type {
  ActivityTemplate,
  LiveOrder,
  OrderMessage,
} from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();
const pricing = usePricingStore();

const orderId = route.params.id as string;
const myId = computed(() => session.userId);

const order = ref<LiveOrder | null>(null);
/** The room never loaded: the order does not exist or is not ours. */
const loadFailed = ref(false);
const messages = ref<OrderMessage[]>([]);
const input = ref('');
const meetCode = ref('');
const busy = ref(false);
const chatList = ref<HTMLElement | null>(null);

const peer = computed(() =>
  order.value ? peerOf(order.value, myId.value) : null,
);
const peerPhone = computed(() =>
  order.value ? peerPhoneOf(order.value, myId.value) : '',
);
const iAmPayer = computed(() => order.value?.payer.id === myId.value);
/** The conversation outlives the activity: a settled chat stays open so
 * people who met can keep talking and rebook right here. Only dead
 * deals (cancelled / forfeited) are read-only. */
const chatOpen = computed(
  () =>
    order.value?.status === 'ACTIVE' || order.value?.status === 'COMPLETED',
);
/** PLAN records stay server-side as the audit trail; the room renders
 *  the pinned card instead. */
const chat = computed(() => messages.value.filter((m) => m.kind !== 'PLAN'));
const cancellable = computed(
  () => order.value !== null && isCancellableNow(order.value),
);

let pollTimer: number | undefined;
let tickTimer: number | undefined;

/** Second-resolution clock driving the live service countdown. */
const nowMs = ref(Date.now());

async function poll(): Promise<void> {
  try {
    const fresh = await getOrder(orderId);
    if (fresh.status === 'AWAITING_PAYMENT') {
      order.value = fresh;
      return;
    }
    // Chat opens the moment the payment lands: escrowed money is the
    // anti-bypass mechanism, so no plan gate on the conversation.
    // A pending rebooking card mutates in place when the host answers,
    // so while one is open the poll refetches the full thread instead
    // of only the tail.
    const awaitingAnswer = messages.value.some(
      (m) =>
        m.kind === 'REQUEST' && parseActivityRequest(m).status === 'PENDING',
    );
    if (awaitingAnswer) {
      const all = await listMessages(orderId);
      const grew = all.length > messages.value.length;
      order.value = fresh;
      messages.value = all;
      if (grew) scrollToBottom();
      return;
    }
    const freshMessages = await listMessages(
      orderId,
      messages.value.length > 0
        ? messages.value[messages.value.length - 1].id
        : undefined,
    );
    order.value = fresh;
    if (freshMessages.length > 0) {
      messages.value.push(...freshMessages);
      scrollToBottom();
    }
  } catch (error) {
    // A 403/404 before the first successful load is a dead link (the
    // order is gone or belongs to someone else): show the error state
    // and stop polling. Anything else is transient; the next tick retries.
    if (
      order.value === null &&
      error instanceof ApiError &&
      (error.statusCode === 403 || error.statusCode === 404)
    ) {
      loadFailed.value = true;
      window.clearInterval(pollTimer);
    }
  }
}

onMounted(() => {
  void poll();
  pollTimer = window.setInterval(() => void poll(), 3000);
  tickTimer = window.setInterval(() => {
    nowMs.value = Date.now();
  }, 1000);
});

onUnmounted(() => {
  window.clearInterval(pollTimer);
  window.clearInterval(tickTimer);
});

function scrollToBottom(): void {
  void nextTick(() => {
    chatList.value?.scrollTo({ top: chatList.value.scrollHeight });
  });
}

async function runAction(
  action: (orderId: string) => Promise<LiveOrder>,
): Promise<void> {
  busy.value = true;
  try {
    order.value = await action(orderId);
  } catch (error) {
    if (error instanceof ApiError && error.body.includes('WRONG_MEET_CODE')) {
      showToast(strings.wrongMeetCodeSnack);
    } else {
      showToast(strings.errorNetwork);
    }
  } finally {
    busy.value = false;
  }
}

/** Either side backs out within the cancel window: full refund. */
async function confirmCancel(): Promise<void> {
  const confirmed = await confirmDialog({
    title: strings.cancelConfirmTitle,
    body: strings.cancelConfirmBody,
    yesLabel: strings.cancelConfirmYes,
    noLabel: strings.cancelConfirmNo,
    danger: true,
  });
  if (!confirmed) return;
  await runAction(cancel);
  if (order.value?.status === 'CANCELLED') {
    showToast(strings.cancelledSnack);
  }
}

/** Host-only: a correct meet code starts the service clock. */
async function startMeet(): Promise<void> {
  await runAction((id) => start(id, meetCode.value.trim()));
}

// In-room safety report: either party can file one; settlement freezes
// while the report is open (the guidelines promise exactly that).
const reportOpen = ref(false);
const reportReason = ref('');
const reportSending = ref(false);

async function submitReport(): Promise<void> {
  const reason = reportReason.value.trim();
  if (reason.length === 0) {
    showToast(strings.reportReasonRequiredHint);
    return;
  }
  reportSending.value = true;
  try {
    await reportOrder(orderId, reason);
    reportOpen.value = false;
    reportReason.value = '';
    showToast(strings.reportSentSnack);
  } catch {
    showToast(strings.errorGeneric);
  } finally {
    reportSending.value = false;
  }
}

async function send(): Promise<void> {
  const text = input.value.trim();
  if (text.length === 0) return;
  input.value = '';
  try {
    const message = await sendMessage(orderId, text);
    messages.value.push(message);
    scrollToBottom();
  } catch {
    showToast(strings.errorMessageNotSent);
  }
}

async function copyPhone(): Promise<void> {
  await navigator.clipboard.writeText(peerPhone.value);
  showToast(strings.phoneCopied);
}

/**
 * Rebooking: the payer composes an activity-request card (template +
 * concrete time + price tier — the same deal terms as an invitation)
 * and sends it into this conversation; the host accepts to form a new
 * order, which the payer then pays as usual.
 */
const rebookOpen = ref(false);
const rebookTemplates = ref<ActivityTemplate[]>([]);
const rebookTemplate = ref<ActivityTemplate | null>(null);
const rebookAt = ref<Date | null>(null);
const rebookBudget = ref(0);
const rebookNote = ref('');
const rebookSending = ref(false);

const rebookTiers = computed(() =>
  rebookTemplate.value
    ? pricing.tiersForScene(rebookTemplate.value.sceneTag)
    : [],
);

async function openRebook(): Promise<void> {
  if (rebookTemplates.value.length === 0) {
    rebookTemplates.value = await fetchTemplates();
  }
  rebookTemplate.value = null;
  rebookAt.value = null;
  rebookNote.value = '';
  rebookOpen.value = true;
}

function pickRebookTemplate(t: ActivityTemplate): void {
  rebookTemplate.value = t;
  rebookBudget.value = pricing.defaultBudgetForScene(t.sceneTag);
}

async function submitRebook(): Promise<void> {
  const template = rebookTemplate.value;
  if (!template) return;
  if (rebookAt.value === null) {
    showToast(strings.publishMeetTimeRequiredHint);
    return;
  }
  rebookSending.value = true;
  try {
    const message = await sendActivityRequest(orderId, {
      templateId: template.id,
      scheduledAt: rebookAt.value,
      budget: rebookBudget.value,
      note: rebookNote.value.trim(),
    });
    messages.value.push(message);
    rebookOpen.value = false;
    showToast(strings.requestSentSnack);
    scrollToBottom();
  } catch (error) {
    if (
      error instanceof ApiError &&
      error.body.includes('REQUEST_ALREADY_PENDING')
    ) {
      rebookOpen.value = false;
      showToast(strings.requestAlreadyPendingSnack);
    } else {
      showToast(strings.errorGeneric);
    }
  } finally {
    rebookSending.value = false;
  }
}

/** The host answers a card; the updated card replaces the old message. */
async function respondRequest(
  message: OrderMessage,
  accept: boolean,
): Promise<void> {
  if (busy.value) return;
  busy.value = true;
  try {
    const updated = await respondActivityRequest(orderId, message.id, accept);
    const index = messages.value.findIndex((m) => m.id === message.id);
    if (index >= 0) messages.value.splice(index, 1, updated);
  } catch {
    showToast(strings.errorGeneric);
  } finally {
    busy.value = false;
  }
}

function requestCardOf(message: OrderMessage) {
  return parseActivityRequest(message);
}

function goPayRequest(newOrderId: string): void {
  void router.push(`/orders/${newOrderId}/pay`);
}

function planWhen(o: LiveOrder): string {
  if (!o.planAt) return '';
  const when = formatDateTime(o.planAt);
  return o.planDurationMinutes > 0
    ? `${when} · ${strings.durationAbout(o.planDurationMinutes)}`
    : when;
}

/**
 * Live countdown while the service runs. The clock is server-anchored
 * (startedAt + the standard duration); when it hits zero the UI shows
 * "settling" and waits for the poll to deliver the COMPLETED state —
 * the client never declares the settlement itself.
 */
const serviceRemainingMs = computed(() => {
  const o = order.value;
  if (!o?.startedAt || o.planDurationMinutes <= 0) return 0;
  return (
    o.startedAt.getTime() + o.planDurationMinutes * 60000 - nowMs.value
  );
});

/** Elapsed fraction of the service window, clamped to [0, 1]. */
const serviceProgress = computed(() => {
  const o = order.value;
  if (!o?.startedAt || o.planDurationMinutes <= 0) return 0;
  const elapsed = nowMs.value - o.startedAt.getTime();
  return Math.min(1, Math.max(0, elapsed / (o.planDurationMinutes * 60000)));
});

function formatCountdown(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}

const badge = computed(() => {
  const o = order.value;
  if (!o) return null;
  if (o.status === 'FORFEITED') {
    return { label: strings.forfeitedBadge, kind: 'muted' };
  }
  if (o.status === 'COMPLETED' || o.status === 'CANCELLED') {
    return { label: strings.chatEndedBadge, kind: 'muted' };
  }
  if (o.startedAt) return { label: strings.startedBadge, kind: 'accent' };
  // The plan was locked at the deal moment: an unstarted active order is
  // simply a confirmed plan waiting for the meet code.
  return { label: strings.planConfirmedBadge, kind: 'accent' };
});
</script>

<template>
  <div class="room-page">
    <PageHeader :title="peer?.name ?? ''" />

    <!-- Dead link: the order is gone or belongs to someone else. -->
    <div v-if="loadFailed" class="center-note">
      <p>{{ strings.orderUnavailableNote }}</p>
      <button class="btn-primary error-back" @click="router.replace('/hall')">
        {{ strings.backToHallCta }}
      </button>
    </div>

    <div v-else-if="!order" class="loading">…</div>

    <!-- Unpaid orders have no conversation: bare fallback for stale links. -->
    <div v-else-if="order.status === 'AWAITING_PAYMENT'" class="center-note">
      {{ strings.chatLockedNote }}
    </div>

    <div v-else-if="order.status === 'CANCELLED'" class="center-note">
      {{ strings.cancelledNote }}
    </div>

    <template v-else>
      <!-- The one pinned plan card: born with the order and read-only. -->
      <section class="plan-card">
        <div class="plan-head">
          <span class="plan-title">{{ strings.planCardTitle }}</span>
          <span v-if="badge" class="plan-badge" :class="badge.kind">
            {{ badge.label }}
          </span>
        </div>
        <!-- The locked meeting place and time, each as a labelled row so
             both sides can read the essentials at a glance. -->
        <div class="plan-rows">
          <div v-if="order.planPlace" class="plan-row">
            <span class="plan-row-label">{{ strings.meetingPointLabel }}</span>
            <span class="plan-row-value">{{ order.planPlace }}</span>
          </div>
          <div v-if="order.planAt" class="plan-row">
            <span class="plan-row-label">{{ strings.detailTimeLabel }}</span>
            <span class="plan-row-value">{{ planWhen(order) }}</span>
          </div>
        </div>
        <template v-if="order.planNote">
          <hr class="rule" />
          <p class="plan-note">{{ order.planNote }}</p>
        </template>

        <!-- The peer phone: revealed once the escrow is in. -->
        <button v-if="peerPhone" class="phone-row" @click="copyPhone">
          ☎ {{ peerPhone }} ⧉
        </button>

        <!-- Lifecycle: exactly one stage is live at a time. -->
        <template v-if="order.status === 'ACTIVE' && !order.startedAt">
          <hr class="rule" />
          <template v-if="iAmPayer">
            <!-- The payer owns the code: tell it to the host in person. -->
            <p class="code-label">{{ strings.meetCodeLabel }}</p>
            <p class="meet-code">{{ order.meetCode }}</p>
            <p class="hint-text">{{ strings.meetCodeHintPayer }}</p>
          </template>
          <div v-else class="code-input-row">
            <input
              v-model="meetCode"
              class="text-field"
              maxlength="4"
              inputmode="numeric"
              :placeholder="strings.meetCodeInputHint"
            />
            <!-- Enabled only once a full 4-digit code is typed, so a
                 stray tap cannot fire a doomed request. -->
            <button
              class="start-btn"
              :disabled="busy || meetCode.trim().length !== 4"
              @click="startMeet"
            >
              {{ strings.startMeetCta }}
            </button>
          </div>
          <button
            v-if="cancellable"
            class="cancel-link"
            :disabled="busy"
            @click="confirmCancel"
          >
            {{ iAmPayer ? strings.cancelCtaPayer : strings.cancelCtaHost }}
          </button>
        </template>

        <!-- Service running: a live countdown and progress bar; the
             escrow settles itself when the clock runs out. -->
        <template v-else-if="order.status === 'ACTIVE' && order.startedAt">
          <hr class="rule" />
          <div class="progress-track">
            <div
              class="progress-fill"
              :style="{ width: `${serviceProgress * 100}%` }"
            ></div>
          </div>
          <p class="status-note countdown-note">
            {{
              serviceRemainingMs > 0
                ? strings.serviceRemainingNote(
                    formatCountdown(serviceRemainingMs),
                  )
                : strings.settlingNote
            }}
          </p>
        </template>

        <p v-else-if="order.status === 'COMPLETED'" class="status-note">
          {{
            iAmPayer
              ? strings.settledPayerNote(formatMoney(order.feeAmount))
              : strings.settledEarnerNote(formatMoney(order.netAmount))
          }}
        </p>

        <p v-else-if="order.status === 'FORFEITED'" class="status-note">
          {{ strings.forfeitedNote }}
        </p>

        <!-- Safety valve: reporting freezes settlement until ops acts. -->
        <button
          v-if="order.status === 'ACTIVE'"
          class="report-link"
          @click="reportOpen = true"
        >
          ⚑ {{ strings.reportCta }}
        </button>
      </section>

      <div ref="chatList" class="chat-list">
        <template v-for="message in chat" :key="message.id">
          <!-- A rebooking card: the payer's new deal terms, answered by
               the host right inside the thread. -->
          <div
            v-if="message.kind === 'REQUEST'"
            class="bubble-row"
            :class="{ mine: message.senderId === myId }"
          >
            <div class="request-card">
              <p class="request-head">{{ strings.requestCardTitle }}</p>
              <p class="request-title">
                {{ requestCardOf(message).title }}
              </p>
              <div class="plan-rows">
                <div class="plan-row">
                  <span class="plan-row-label">{{ strings.detailTimeLabel }}</span>
                  <span class="plan-row-value">
                    {{ formatDateTime(requestCardOf(message).scheduledAt) }}
                  </span>
                </div>
                <div class="plan-row">
                  <span class="plan-row-label">{{ strings.meetingPointLabel }}</span>
                  <span class="plan-row-value">
                    {{ requestCardOf(message).meetingPoint }}
                  </span>
                </div>
                <div class="plan-row">
                  <span class="plan-row-label">{{ strings.hostingFeeLabel }}</span>
                  <span class="plan-row-value">
                    {{ formatMoney(requestCardOf(message).amount) }}
                  </span>
                </div>
              </div>
              <p v-if="requestCardOf(message).note" class="request-note">
                “{{ requestCardOf(message).note }}”
              </p>

              <!-- Card state: pending shows answer buttons to the host
                   and a waiting note to the payer; accepted routes the
                   payer to checkout; declined just says so. -->
              <template v-if="requestCardOf(message).status === 'PENDING'">
                <div v-if="!iAmPayer" class="request-actions">
                  <button
                    class="request-decline"
                    :disabled="busy"
                    @click="respondRequest(message, false)"
                  >
                    {{ strings.requestDeclineCta }}
                  </button>
                  <button
                    class="request-accept"
                    :disabled="busy"
                    @click="respondRequest(message, true)"
                  >
                    {{ strings.requestAcceptCta }}
                  </button>
                </div>
                <p v-else class="request-state">
                  {{ strings.requestWaitingNote }}
                </p>
              </template>
              <template v-else-if="requestCardOf(message).status === 'ACCEPTED'">
                <button
                  v-if="iAmPayer"
                  class="request-accept wide"
                  @click="goPayRequest(requestCardOf(message).orderId)"
                >
                  {{ strings.requestGoPayCta }}
                </button>
                <p v-if="iAmPayer" class="request-state">
                  {{ strings.requestAcceptedPayerNote }}
                </p>
                <p v-else class="request-state">
                  {{ strings.requestAcceptedEarnerNote }}
                </p>
              </template>
              <p v-else class="request-state">
                {{ strings.requestDeclinedNote }}
              </p>
            </div>
          </div>

          <div
            v-else
            class="bubble-row"
            :class="{ mine: message.senderId === myId }"
          >
            <div class="bubble" :class="{ mine: message.senderId === myId }">
              {{ message.text }}
            </div>
          </div>
        </template>
      </div>

      <div v-if="chatOpen" class="input-bar">
        <!-- Rebooking entry: payers only — the payer prices and schedules
             the next activity, mirroring the invitation flow. -->
        <button
          v-if="iAmPayer"
          class="rebook-btn"
          :aria-label="strings.rebookCta"
          @click="openRebook"
        >
          <svg
            viewBox="0 0 24 24"
            width="20"
            height="20"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
          >
            <path d="M12 5v14M5 12h14" />
          </svg>
        </button>
        <input
          v-model="input"
          class="text-field"
          :placeholder="strings.messageInputHint"
          @keyup.enter="send"
        />
        <button class="send-btn" aria-label="send" @click="send">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor">
            <path d="M3 20l18-8L3 4v6l12 2-12 2v6z" />
          </svg>
        </button>
      </div>
      <!-- Dead deals (cancelled / forfeited): history stays readable. -->
      <div v-else class="readonly-note">
        🔒 {{ strings.chatReadOnlyNote }}
      </div>

      <!-- Rebook sheet: template + concrete time + price tier + note. -->
      <Teleport to="body">
        <div
          v-if="rebookOpen"
          class="sheet-overlay"
          @click.self="rebookOpen = false"
        >
          <div class="sheet">
            <h3 class="sheet-title">
              {{ strings.rebookSheetTitle(peer?.name ?? '') }}
            </h3>

            <p class="sheet-label">{{ strings.rebookPickTemplateLabel }}</p>
            <div class="template-list">
              <button
                v-for="t in rebookTemplates"
                :key="t.id"
                class="template-option"
                :class="{ selected: rebookTemplate?.id === t.id }"
                @click="pickRebookTemplate(t)"
              >
                <img class="template-cover" :src="t.imageUrl" alt="" />
                <span class="template-text">
                  <span class="template-title">{{ t.title }}</span>
                  <span class="template-meta">
                    {{
                      [t.meetingPoint, t.area]
                        .filter((s) => s.length > 0)
                        .join(' · ')
                    }}
                  </span>
                </span>
              </button>
            </div>

            <template v-if="rebookTemplate">
              <p class="sheet-label">{{ strings.publishMeetTimeLabel }}</p>
              <MeetTimePicker v-model="rebookAt" />

              <p class="sheet-label">{{ strings.hostingFeeLabel }}</p>
              <div class="chips">
                <button
                  v-for="tier in rebookTiers"
                  :key="tier"
                  class="chip"
                  :class="{ selected: rebookBudget === tier }"
                  @click="rebookBudget = tier"
                >
                  {{ formatMoney(tier) }}
                </button>
              </div>

              <textarea
                v-model="rebookNote"
                class="text-field"
                rows="2"
                maxlength="300"
                :placeholder="strings.inviteNoteHint"
              ></textarea>
              <button
                class="btn-primary"
                :disabled="rebookSending"
                @click="submitRebook"
              >
                {{ strings.inviteSendCta }}
              </button>
            </template>
          </div>
        </div>
      </Teleport>

      <!-- Report sheet: a reason and a submit, nothing more. -->
      <Teleport to="body">
        <div
          v-if="reportOpen"
          class="sheet-overlay"
          @click.self="reportOpen = false"
        >
          <div class="sheet">
            <h3 class="sheet-title">{{ strings.reportSheetTitle }}</h3>
            <p class="report-sub">{{ strings.reportSheetSub }}</p>
            <textarea
              v-model="reportReason"
              class="text-field"
              rows="4"
              maxlength="500"
              :placeholder="strings.reportReasonHint"
            ></textarea>
            <button
              class="btn-primary"
              :disabled="reportSending"
              @click="submitReport"
            >
              {{ strings.reportSubmitCta }}
            </button>
          </div>
        </div>
      </Teleport>
    </template>
  </div>
</template>

<style scoped>
.room-page {
  height: 100dvh;
  background: var(--color-background);
  display: flex;
  flex-direction: column;
}

.loading,
.center-note {
  padding: 100px 32px 0;
  text-align: center;
  color: var(--color-text-secondary);
  font-size: 14px;
}

.report-link {
  margin-top: 10px;
  font-size: 12px;
  color: var(--color-text-hint);
}

.report-sub {
  margin: -4px 0 0;
  font-size: 13px;
  color: var(--color-text-secondary);
}

.plan-card {
  margin: 10px 16px;
  padding: 14px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  flex-shrink: 0;
}

.plan-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.plan-title {
  font-size: 13px;
  font-weight: 700;
}

.plan-badge {
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
}

.plan-badge.accent {
  background: var(--color-accent-soft);
  color: var(--color-accent);
}

.plan-badge.muted {
  background: var(--color-other-bubble);
  color: var(--color-text-hint);
}

.plan-rows {
  margin-top: 10px;
  display: flex;
  flex-direction: column;
  gap: 7px;
}

.plan-row {
  display: flex;
  align-items: baseline;
  gap: 10px;
}

.plan-row-label {
  flex-shrink: 0;
  font-size: 12px;
  color: var(--color-text-hint);
}

.plan-row-value {
  font-size: 13.5px;
  font-weight: 700;
}

.rule {
  border: none;
  border-top: 1px solid var(--color-divider);
  margin: 10px 0;
}

.plan-note {
  margin: 0;
  font-size: 13px;
  line-height: 1.45;
}

.phone-row {
  margin-top: 10px;
  font-size: 12.5px;
  font-weight: 600;
  display: block;
  text-align: left;
}

.code-label {
  margin: 0;
  font-size: 12px;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.meet-code {
  margin: 4px 0 4px;
  font-size: 28px;
  font-weight: 800;
  letter-spacing: 8px;
}

.code-input-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.code-input-row .text-field {
  flex: 1;
}

.start-btn {
  padding: 12px 16px;
  border-radius: 12px;
  background: var(--color-dark-card);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
  flex-shrink: 0;
}

.start-btn:disabled {
  opacity: 0.4;
}

.error-back {
  width: auto;
  margin-top: 20px;
  padding: 12px 36px;
}

.cancel-link {
  margin-top: 8px;
  font-size: 12px;
  color: var(--color-text-hint);
  display: block;
  text-align: left;
}

.status-note {
  margin: 10px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
}

.progress-track {
  margin-top: 12px;
  height: 5px;
  border-radius: 999px;
  background: var(--color-surface);
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  border-radius: 999px;
  background: var(--color-accent);
  transition: width 1s linear;
}

.countdown-note {
  margin-top: 8px;
  font-weight: 600;
  color: var(--color-text-secondary);
  font-variant-numeric: tabular-nums;
}

.request-card {
  width: min(320px, 82%);
  padding: 13px 14px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-background);
}

.request-head {
  margin: 0;
  font-size: 11px;
  font-weight: 700;
  color: var(--color-accent);
}

.request-title {
  margin: 4px 0 10px;
  font-size: 14.5px;
  font-weight: 700;
}

.request-note {
  margin: 10px 0 0;
  font-size: 12.5px;
  line-height: 1.5;
  color: var(--color-text-secondary);
}

.request-actions {
  margin-top: 12px;
  display: flex;
  gap: 8px;
}

.request-accept {
  flex: 1;
  padding: 9px 0;
  border-radius: 10px;
  background: var(--color-text-primary);
  color: #fff;
  font-size: 13px;
  font-weight: 700;
}

.request-accept.wide {
  width: 100%;
  margin-top: 12px;
}

.request-decline {
  flex: 1;
  padding: 9px 0;
  border-radius: 10px;
  border: 1px solid var(--color-border);
  color: var(--color-text-secondary);
  font-size: 13px;
  font-weight: 600;
  background: transparent;
}

.request-state {
  margin: 10px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
}

.rebook-btn {
  flex-shrink: 0;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  border: 1px solid var(--color-border);
  color: var(--color-text-primary);
  background: var(--color-background);
}

.sheet-overlay {
  position: fixed;
  inset: 0;
  background: rgb(0 0 0 / 40%);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 1000;
}

.sheet {
  width: min(480px, 100%);
  max-height: 86dvh;
  overflow-y: auto;
  background: var(--color-background);
  border-radius: 24px 24px 0 0;
  padding: 24px 24px calc(24px + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* The sheet is a capped flex column: without this, overflowing content
   squashes the children (the send button collapses) instead of scrolling. */
.sheet > * {
  flex-shrink: 0;
}

.sheet-title {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
}

.sheet-label {
  margin: 4px 0 -4px;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text-secondary);
}

.template-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.template-option {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 9px 10px;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-background);
  text-align: left;
}

.template-option.selected {
  border-color: var(--color-accent);
  background: var(--color-accent-soft);
}

.template-cover {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  object-fit: cover;
  flex-shrink: 0;
}

.template-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.template-title {
  font-size: 13.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.template-meta {
  font-size: 11.5px;
  color: var(--color-text-hint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.chat-list {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

.bubble-row {
  display: flex;
  margin-bottom: 10px;
}

.bubble-row.mine {
  justify-content: flex-end;
}

.bubble {
  max-width: 280px;
  padding: 10px 14px;
  border-radius: 16px;
  background: var(--color-other-bubble);
  font-size: 15px;
  word-break: break-word;
}

.bubble.mine {
  background: var(--color-my-bubble);
  color: var(--color-my-bubble-text);
}

.input-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 16px calc(12px + env(safe-area-inset-bottom));
  flex-shrink: 0;
}

.input-bar .text-field {
  flex: 1;
}

.send-btn {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  background: var(--color-dark-card);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.readonly-note {
  padding: 8px 0 calc(14px + env(safe-area-inset-bottom));
  text-align: center;
  font-size: 12.5px;
  color: var(--color-text-hint);
  flex-shrink: 0;
}
</style>
