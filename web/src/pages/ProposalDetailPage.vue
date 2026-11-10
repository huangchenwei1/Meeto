<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { ApiError } from '@/api/client';
import {
  fetchProposal,
  fetchProposalInvites,
  inviteToProposal,
  selectInvite,
} from '@/api/proposals';
import AppAvatar from '@/components/AppAvatar.vue';
import MeetTimePicker from '@/components/MeetTimePicker.vue';
import PageHeader from '@/components/PageHeader.vue';
import VerifiedBadge from '@/components/VerifiedBadge.vue';
import { PROPOSAL_SLOT_WINDOWS } from '@/constants/proposalSlots';
import { strings } from '@/constants/strings';
import { usePricingStore } from '@/stores/pricing';
import { useSessionStore } from '@/stores/session';
import { confirmDialog } from '@/utils/confirm';
import { formatDateTime, formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type { InvitationRecord, ProposalCard } from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();
const pricing = usePricingStore();

const proposalId = route.params.id as string;

const proposal = ref<ProposalCard | null>(null);
const invites = ref<InvitationRecord[]>([]);
const selecting = ref(false);
const inviteSheetOpen = ref(false);
const inviteNote = ref('');
/** The deal terms the inviter picks: concrete time + price tier. */
const inviteAt = ref<Date | null>(null);
const inviteBudget = ref(0);

const isMine = computed(() => proposal.value?.hostId === session.userId);
const isHost = computed(() => session.isHost);

/** Platform tiers for the pitch's scene (whole currency units). */
const tiers = computed(() =>
  proposal.value ? pricing.tiersForScene(proposal.value.sceneTag) : [],
);

/** The picker window is the host's declared availability slot. */
const slotWindow = computed(
  () =>
    PROPOSAL_SLOT_WINDOWS[proposal.value?.timeSlot ?? ''] ??
    PROPOSAL_SLOT_WINDOWS.ANYTIME,
);

function openInviteSheet(): void {
  if (!proposal.value) return;
  inviteAt.value = null;
  inviteBudget.value = pricing.defaultBudgetForScene(proposal.value.sceneTag);
  inviteSheetOpen.value = true;
}

let pollTimer: number | undefined;

async function load(): Promise<void> {
  try {
    const p = await fetchProposal(proposalId);
    proposal.value = p;
    if (p.hostId === session.userId) {
      invites.value = await fetchProposalInvites(proposalId);
    }
  } catch {
    // Keep the last known state; the next poll retries.
  }
}

onMounted(() => {
  void load();
  // The invite pool is the host's main waiting surface, so it polls.
  pollTimer = window.setInterval(() => void load(), 5000);
});

onUnmounted(() => window.clearInterval(pollTimer));

function hostMetaLine(p: ProposalCard): string {
  const record =
    p.hostCompletedActivities > 0
      ? strings.hostCompletedLabel(p.hostCompletedActivities)
      : strings.hostNewLabel;
  return p.hostMeta.length === 0 ? record : `${p.hostMeta} · ${record}`;
}

function locationLine(p: ProposalCard): string {
  return [p.hostCity, p.area].filter((s) => s.length > 0).join(' · ');
}

async function sendInvite(): Promise<void> {
  if (!proposal.value) return;
  // The invitation carries the deal terms, so the time is required.
  if (inviteAt.value === null) {
    showToast(strings.publishMeetTimeRequiredHint);
    return;
  }
  inviteSheetOpen.value = false;
  // An empty note still carries context server-side via the pitch itself.
  const note =
    inviteNote.value.trim().length > 0
      ? inviteNote.value.trim()
      : proposal.value.title;
  try {
    await inviteToProposal(proposalId, {
      scheduledAt: inviteAt.value,
      budget: inviteBudget.value,
      note,
    });
    showToast(strings.inviteSentSnack);
    proposal.value = { ...proposal.value, hasInvited: true };
    void load();
  } catch (error) {
    if (error instanceof ApiError && error.verificationRequired) {
      const go = await confirmDialog({
        title: strings.verifyDialogTitle,
        body: strings.verifyDialogBody,
        yesLabel: strings.verifyNow,
        noLabel: strings.verifyLater,
      });
      if (go) await router.push('/verification');
      return;
    }
    if (error instanceof ApiError && error.body.includes('INVITE_ALREADY_PENDING')) {
      showToast(strings.inviteAlreadyPendingSnack);
    } else if (error instanceof ApiError && error.body.includes('PROPOSAL_NOT_OPEN')) {
      showToast(strings.proposalNotOpenSnack);
    } else {
      showToast(strings.errorGeneric);
    }
  }
}

/**
 * The host picks one inviter; the plan locks to that invitation's deal
 * terms (template meeting point + the inviter's picked time and tier),
 * so selection is one tap. The conversation only exists once the
 * inviter pays.
 */
async function submitSelect(invitation: InvitationRecord): Promise<void> {
  if (selecting.value) return;
  selecting.value = true;
  try {
    await selectInvite(proposalId, invitation.id);
    showToast(strings.selectInviterDoneSnack);
    void load();
  } catch {
    showToast(strings.errorGeneric);
  } finally {
    selecting.value = false;
  }
}
</script>

<template>
  <div class="detail-page">
    <PageHeader />

    <div v-if="!proposal" class="loading">…</div>

    <template v-else>
      <div class="content">
        <p class="scene">
          {{ strings.sceneLabel(proposal.sceneTag) }}
          <span v-if="proposal.status !== 'OPEN'" class="closed-note">
            · {{ strings.proposalNotOpenSnack }}
          </span>
        </p>
        <h1 class="title">{{ proposal.title }}</h1>

        <!-- The host's signature card: inviting is picking a person. -->
        <RouterLink
          v-if="!isMine"
          class="host-card"
          :to="`/users/${proposal.hostId}`"
        >
          <AppAvatar :url="proposal.hostAvatarUrl" :name="proposal.hostName" :size="46" />
          <div class="host-text">
            <span class="host-name">
              {{ proposal.hostName }}
              <VerifiedBadge v-if="proposal.hostIsVerified" />
            </span>
            <span class="host-meta">{{ hostMetaLine(proposal) }}</span>
          </div>
          <span class="chevron">›</span>
        </RouterLink>

        <!-- The place comes from the template; the time is only a rough
             window here — the inviter picks the concrete time. -->
        <div class="info-panel">
          <div class="info-row">
            <span class="info-label">{{ strings.proposalTimeSlotLabel }}</span>
            <span class="info-value">
              {{ strings.proposalTimeSlotName(proposal.timeSlot) }}
            </span>
          </div>
          <div v-if="proposal.meetingPoint" class="info-row">
            <span class="info-label">{{ strings.meetingPointLabel }}</span>
            <span class="info-value">{{ proposal.meetingPoint }}</span>
          </div>
          <div v-if="locationLine(proposal)" class="info-row">
            <span class="info-label">{{ strings.detailAreaLabel }}</span>
            <span class="info-value">{{ locationLine(proposal) }}</span>
          </div>
          <div v-if="proposal.durationLabel" class="info-row">
            <span class="info-label">{{ strings.detailDurationLabel }}</span>
            <span class="info-value">{{ proposal.durationLabel }}</span>
          </div>
          <div v-if="proposal.inviteCount > 0" class="info-row">
            <span class="info-label">{{ strings.detailInvitesLabel }}</span>
            <span class="info-value">
              {{ strings.proposalInviteCount(proposal.inviteCount) }}
            </span>
          </div>
        </div>

        <p v-if="proposal.description" class="detail-text">
          {{ proposal.description }}
        </p>

        <!-- User viewers get the fee RULES only: the amount is theirs to
             pick in the invite sheet, so no price shows while browsing. -->
        <section v-if="!isMine && !isHost" class="card">
          <div class="budget-head">
            <span class="budget-label">{{ strings.hostingFeeLabel }}</span>
            <!-- No amount while browsing: the inviter picks the tier in
                 the invite sheet, and this note says so. -->
            <span class="budget-pick-note">{{ strings.proposalFeePickNote }}</span>
          </div>
          <hr class="rule" />
          <p class="budget-rule">✓ {{ strings.budgetRuleUserService }}</p>
          <p class="budget-rule">✓ {{ strings.budgetRuleUserExpenses }}</p>
          <p class="budget-rule">✓ {{ strings.budgetRuleUserEscrow }}</p>
        </section>

        <!-- The host's live invite pool, mirror of the candidate pool.
             Once the pitch is matched the pool is moot: the deal lives
             in the order room, reachable from the activities board. -->
        <section v-if="isMine && proposal.status === 'OPEN'" class="card">
          <div class="card-head">
            <span class="card-title">{{ strings.proposalInvitesTitle }}</span>
          </div>
          <p v-if="invites.length === 0" class="empty-note">
            {{ strings.proposalInvitesEmpty }}
          </p>
          <div
            v-for="invitation in invites"
            :key="invitation.id"
            class="invite-row"
            @click="router.push(`/users/${invitation.fromId}`)"
          >
            <AppAvatar :url="invitation.fromAvatarUrl" :name="invitation.fromName" :size="42" />
            <div class="invite-main">
              <span class="invite-name">
                {{ invitation.fromName }}
                <VerifiedBadge v-if="invitation.fromVerified" />
              </span>
              <span class="invite-meta">{{ invitation.fromMeta }}</span>
              <!-- Each inviter brings their own deal terms. -->
              <span v-if="invitation.scheduledAt" class="invite-terms">
                {{ formatDateTime(invitation.scheduledAt) }}
                · {{ formatMoney(invitation.amount) }}
              </span>
              <span v-if="invitation.note" class="invite-note">
                “{{ invitation.note }}”
              </span>
            </div>
            <button
              class="approve-btn"
              :disabled="selecting"
              @click.stop="submitSelect(invitation)"
            >
              {{ strings.approveCta }}
            </button>
          </div>
        </section>
      </div>

      <!-- Inviting is a user action on open pitches. -->
      <footer
        v-if="!isMine && !isHost && proposal.status === 'OPEN'"
        class="bottom-bar"
      >
        <button
          class="invite-btn"
          :disabled="proposal.hasInvited"
          @click="openInviteSheet"
        >
          {{ proposal.hasInvited ? strings.invitedBadge : strings.hostInviteCta }}
        </button>
      </footer>

      <!-- Invitation sheet: the inviter picks the concrete time (inside
           the host's declared window) and the price tier. -->
      <Teleport to="body">
        <div
          v-if="inviteSheetOpen"
          class="sheet-overlay"
          @click.self="inviteSheetOpen = false"
        >
          <div class="sheet">
            <h3 class="sheet-title">
              {{ strings.inviteSheetTitle(proposal.hostName) }}
            </h3>
            <div class="sheet-fee-row">
              <span class="scene-pill">{{ strings.sceneLabel(proposal.sceneTag) }}</span>
              <span class="sheet-slot">
                {{ strings.proposalTimeSlotName(proposal.timeSlot) }}
              </span>
            </div>

            <p class="sheet-label">{{ strings.publishMeetTimeLabel }}</p>
            <MeetTimePicker
              v-model="inviteAt"
              :start-hour="slotWindow.startHour"
              :end-hour="slotWindow.endHour"
            />

            <p class="sheet-label">{{ strings.hostingFeeLabel }}</p>
            <div class="chips">
              <button
                v-for="tier in tiers"
                :key="tier"
                class="chip"
                :class="{ selected: inviteBudget === tier }"
                @click="inviteBudget = tier"
              >
                {{ formatMoney(tier) }}
              </button>
            </div>
            <p class="hint-text">{{ strings.serviceFeeNoteUser }}</p>

            <textarea
              v-model="inviteNote"
              class="text-field"
              rows="3"
              maxlength="300"
              :placeholder="strings.inviteNoteHint"
            ></textarea>
            <p class="hint-text">
              {{ strings.inviteFeeNote(formatMoney(inviteBudget)) }}
            </p>
            <button class="btn-primary" @click="sendInvite">
              {{ strings.inviteSendCta }}
            </button>
          </div>
        </div>
      </Teleport>
    </template>
  </div>
</template>

<style scoped>
.detail-page {
  min-height: 100dvh;
  background: var(--color-background);
  padding-bottom: 100px;
}

.loading {
  padding-top: 100px;
  text-align: center;
  color: var(--color-text-hint);
}

.content {
  padding: 4px 20px 24px;
}

.scene {
  margin: 0;
  font-size: 13px;
  font-weight: 600;
  color: var(--color-accent);
}

.closed-note {
  color: var(--color-text-hint);
}

.title {
  margin: 6px 0 0;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.3;
}

.host-card {
  margin-top: 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--color-border);
  border-radius: 16px;
}

.host-text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.host-name {
  font-size: 15px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.host-meta {
  font-size: 12px;
  color: var(--color-text-hint);
}

.chevron {
  color: var(--color-text-hint);
  font-size: 20px;
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
  margin-top: 18px;
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

.empty-note {
  margin: 10px 0 2px;
  font-size: 12.5px;
  color: var(--color-text-hint);
}

.invite-row {
  display: flex;
  align-items: flex-start;
  gap: 11px;
  padding: 10px 0;
  cursor: pointer;
}

.invite-row + .invite-row {
  border-top: 1px solid var(--color-divider);
}

.invite-main {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.invite-name {
  font-size: 14.5px;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.invite-meta {
  font-size: 12px;
  color: var(--color-text-hint);
}

.invite-terms {
  font-size: 12.5px;
  font-weight: 600;
}

.invite-note {
  font-size: 12.5px;
  line-height: 1.4;
  color: var(--color-text-secondary);
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

.budget-pick-note {
  font-size: 12px;
  color: var(--color-text-hint);
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
  display: flex;
  align-items: center;
  gap: 16px;
  z-index: 40;
}

.invite-btn {
  flex: 1;
  padding: 14px 24px;
  border-radius: 14px;
  background: var(--color-text-primary);
  color: #fff;
  font-size: 15px;
  font-weight: 700;
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

.sheet-label {
  margin: 4px 0 -4px;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text-secondary);
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.sheet-title {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
}

.sheet-fee-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.scene-pill {
  padding: 6px 12px;
  border-radius: 999px;
  background: var(--color-text-primary);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
}

.sheet-slot {
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text-secondary);
}

textarea.text-field {
  resize: vertical;
}
</style>
