<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { createPost, fetchTemplates } from '@/api/posts';
import { createProposal } from '@/api/proposals';
import MeetTimePicker from '@/components/MeetTimePicker.vue';
import PageHeader from '@/components/PageHeader.vue';
import { PROPOSAL_SLOT_OPTIONS } from '@/constants/proposalSlots';
import { strings } from '@/constants/strings';
import { usePricingStore } from '@/stores/pricing';
import { useSessionStore } from '@/stores/session';
import { formatMoney } from '@/utils/format';
import { showToast } from '@/utils/toast';
import type { ActivityTemplate } from '@/types/models';

const route = useRoute();
const router = useRouter();
const session = useSessionStore();
const pricing = usePricingStore();

const isHost = computed(() => session.isHost);

const scene = ref(pricing.scenes[0]);
const budget = ref(pricing.defaultBudgetForScene(scene.value));
const title = ref('');
const description = ref('');
const submitting = ref(false);

/**
 * User mode: the concrete meeting time, picked via the platform picker
 * (hosts work 09:00-22:00, activities run the standard 2h).
 */
const meetAt = ref<Date | null>(null);

/**
 * Host mode: a pitch is a service shelf listing. The host declares a
 * rough availability window only — the inviting user later picks the
 * concrete time (inside it) and the price tier.
 */
const timeSlot = ref('ANYTIME');

/**
 * Publishing is template-only: every activity launches from the curated
 * shelf, which fixes the whole envelope — scene (and with it the budget
 * tiers and cover), partner venue, exact meeting point and district. The
 * publisher brings only their own words and a concrete meeting time; the
 * duration is the platform standard.
 */
const template = ref<ActivityTemplate | null>(null);
const templates = ref<ActivityTemplate[]>([]);
const templatesLoaded = ref(false);

function launch(t: ActivityTemplate): void {
  template.value = t;
  if (pricing.scenes.includes(t.sceneTag)) {
    scene.value = t.sceneTag;
    budget.value = pricing.defaultBudgetForScene(t.sceneTag);
  }
}

onMounted(async () => {
  try {
    templates.value = await fetchTemplates();
  } finally {
    templatesLoaded.value = true;
  }
  const templateId = route.query.template;
  if (typeof templateId !== 'string' || templateId.length === 0) return;
  const found = templates.value.find((t) => t.id === templateId);
  if (found) launch(found);
});

async function submit(): Promise<void> {
  if (!template.value) return;
  // The author's own words are required: no pre-written copy.
  const titleText = title.value.trim();
  const descText = description.value.trim();
  if (titleText.length === 0 || descText.length === 0) {
    showToast(strings.publishFieldsRequiredHint);
    return;
  }
  // Users must pick a concrete meeting time: the plan locks at
  // selection. Hosts only declare an availability window.
  if (!isHost.value && meetAt.value === null) {
    showToast(strings.publishMeetTimeRequiredHint);
    return;
  }
  submitting.value = true;
  try {
    if (isHost.value) {
      await createProposal({
        templateId: template.value.id,
        title: titleText,
        description: descText,
        timeSlot: timeSlot.value,
      });
    } else {
      await createPost({
        templateId: template.value.id,
        title: titleText,
        description: descText,
        scheduledAt: meetAt.value as Date,
        budget: budget.value,
      });
    }
    showToast(strings.publishSuccess);
    router.back();
  } catch {
    submitting.value = false;
    showToast(strings.errorGeneric);
  }
}
</script>

<template>
  <div class="composer-page">
    <PageHeader
      :title="isHost ? strings.proposalComposerTitle : strings.publishTitle"
    />

    <!-- Step 1, template-only publishing: every activity launches from
         the curated shelf, keeping content and districts under platform
         control. No free-form entry exists. -->
    <div v-if="!template" class="picker">
      <p class="picker-sub">{{ strings.publishPickTemplateSub }}</p>

      <div v-if="!templatesLoaded" class="picker-note">…</div>
      <div v-else-if="templates.length === 0" class="picker-note">
        {{ strings.templatesEmpty }}
      </div>

      <article
        v-for="t in templates"
        :key="t.id"
        class="picker-card"
        @click="launch(t)"
      >
        <img class="picker-cover" :src="t.imageUrl" alt="" />
        <div class="picker-text">
          <p class="picker-title">{{ t.title }}</p>
          <p class="picker-desc">{{ t.description }}</p>
          <p class="picker-meta">
            <span class="picker-scene">{{ strings.sceneLabel(t.sceneTag) }}</span>
            <template v-if="t.venueName"> · {{ t.venueName }}</template>
            <template v-if="t.area"> · {{ t.area }}</template>
            <template v-if="t.durationLabel"> · {{ t.durationLabel }}</template>
          </p>
        </div>
        <span class="picker-launch">{{ strings.templateLaunchCta }}</span>
      </article>
    </div>

    <!-- Step 2: the launched platform activity, quoted. Scene, venue,
         meeting point, district and cover are all locked by the template;
         the author writes the title and description in their own words
         and picks a concrete meeting time. -->
    <div v-else class="form">
      <p class="label">{{ strings.publishTemplateQuoteLabel }}</p>
      <div class="quote-card">
        <img
          v-if="template.imageUrl"
          class="quote-cover"
          :src="template.imageUrl"
          alt=""
        />
        <div class="quote-text">
          <p class="quote-tags">
            <span class="quote-scene">{{ strings.sceneLabel(template.sceneTag) }}</span>
            <span v-if="template.area" class="quote-duration">{{ template.area }}</span>
            <span v-if="template.durationLabel" class="quote-duration">
              {{ template.durationLabel }}
            </span>
          </p>
          <p class="quote-title">{{ template.title }}</p>
        </div>
      </div>

      <!-- The meeting place is template-locked and shown as its own block
           so the publisher sees exactly where everyone will meet. -->
      <template v-if="template.meetingPoint">
        <p class="label">{{ strings.meetingPointLabel }}</p>
        <div class="place-card">
          <svg
            class="place-pin"
            viewBox="0 0 24 24"
            width="18"
            height="18"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <path d="M12 21s-7-5.5-7-11a7 7 0 0 1 14 0c0 5.5-7 11-7 11z" />
            <circle cx="12" cy="10" r="2.6" />
          </svg>
          <div class="place-text">
            <p class="place-main">{{ template.meetingPoint }}</p>
            <p class="place-sub">
              {{
                [template.venueName, template.area]
                  .filter((s) => s.length > 0)
                  .join(' · ')
              }}
            </p>
          </div>
        </div>
      </template>

      <!-- Hosts do not price their pitch: the inviting user picks the
           tier later, so the fee chips only exist in user mode. -->
      <template v-if="!isHost">
        <p class="label">{{ strings.hostingFeeLabel }}</p>
        <div class="chips">
          <button
            v-for="tier in pricing.tiersForScene(scene)"
            :key="tier"
            class="chip"
            :class="{ selected: budget === tier }"
            @click="budget = tier"
          >
            {{ formatMoney(tier) }}
          </button>
        </div>
        <p class="hint-text">{{ strings.serviceFeeNoteUser }}</p>

        <!-- On-site expenses are always on the publisher ("my treat"):
             a platform rule, shown as fixed info rather than a choice. -->
        <p class="label">{{ strings.expenseLabel }}</p>
        <div class="chips">
          <span class="chip selected">{{ strings.expenseTreat }}</span>
        </div>
        <p class="hint-text">{{ strings.expenseNoteTreat }}</p>
      </template>

      <p class="label">{{ strings.publishFieldTitle }}</p>
      <input
        v-model="title"
        class="text-field"
        maxlength="80"
        :placeholder="isHost ? strings.proposalTitleHint : strings.publishPhTitle"
      />

      <p class="label">
        {{ strings.publishFieldDesc }}
        <span class="label-hint">{{ strings.publishFieldDescHint }}</span>
      </p>
      <textarea
        v-model="description"
        class="text-field"
        rows="4"
        maxlength="300"
        :placeholder="isHost ? strings.proposalDescHint : strings.publishPhDesc"
      ></textarea>

      <!-- Host mode: only a rough availability window. User mode: the
           exact meeting time, picked from in-window slots only. -->
      <template v-if="isHost">
        <p class="label">{{ strings.proposalTimeSlotLabel }}</p>
        <div class="chips">
          <button
            v-for="slot in PROPOSAL_SLOT_OPTIONS"
            :key="slot"
            class="chip"
            :class="{ selected: timeSlot === slot }"
            @click="timeSlot = slot"
          >
            {{ strings.proposalTimeSlotName(slot) }}
          </button>
        </div>
        <p class="hint-text">{{ strings.proposalTimeSlotHint }}</p>
      </template>
      <template v-else>
        <p class="label">{{ strings.publishMeetTimeLabel }}</p>
        <MeetTimePicker v-model="meetAt" />
        <p class="hint-text">{{ strings.publishMeetTimeHint }}</p>
      </template>
    </div>

    <footer v-if="template" class="bottom-bar">
      <button class="btn-primary" :disabled="submitting" @click="submit">
        {{ submitting ? '...' : strings.publishSubmit }}
      </button>
    </footer>
  </div>
</template>

<style scoped>
.composer-page {
  min-height: 100dvh;
  background: var(--color-background);
  padding-bottom: 96px;
}

.form {
  padding: 8px 18px 24px;
}

.picker {
  padding: 4px 18px 24px;
}

.picker-sub {
  margin: 4px 0 14px;
  font-size: 13px;
  color: var(--color-text-secondary);
}

.picker-note {
  padding: 48px 0;
  text-align: center;
  font-size: 13px;
  color: var(--color-text-hint);
}

.picker-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  margin-bottom: 10px;
  cursor: pointer;
}

.picker-cover {
  width: 72px;
  height: 72px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
  background: var(--color-surface);
}

.picker-text {
  flex: 1;
  min-width: 0;
}

.picker-title {
  margin: 0;
  font-size: 15.5px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.picker-desc {
  margin: 4px 0 0;
  font-size: 12.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.picker-meta {
  margin: 8px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.picker-scene {
  color: var(--color-accent);
  font-weight: 600;
}

.picker-launch {
  flex-shrink: 0;
  padding: 7px 16px;
  border-radius: 999px;
  background: var(--color-button-soft);
  font-size: 12.5px;
  font-weight: 700;
}

.label {
  margin: 18px 0 8px;
  font-size: 13px;
  font-weight: 700;
  color: var(--color-text-secondary);
}

.label-hint {
  font-weight: 400;
  color: var(--color-text-hint);
  margin-left: 6px;
  font-size: 12px;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.quote-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: var(--color-surface);
  border-radius: 14px;
}

.quote-cover {
  width: 48px;
  height: 48px;
  border-radius: 10px;
  object-fit: cover;
  flex-shrink: 0;
}

.quote-text {
  flex: 1;
  min-width: 0;
}

.quote-tags {
  margin: 0;
  display: flex;
  align-items: center;
  gap: 8px;
}

.quote-scene {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--color-dark-card);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
}

.quote-duration {
  font-size: 11.5px;
  color: var(--color-text-hint);
}

.quote-title {
  margin: 6px 0 0;
  font-size: 14px;
  font-weight: 700;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.place-card {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 13px 14px;
  background: var(--color-surface);
  border-radius: 14px;
}

.place-pin {
  flex-shrink: 0;
  color: var(--color-accent);
}

.place-text {
  flex: 1;
  min-width: 0;
}

.place-main {
  margin: 0;
  font-size: 14px;
  font-weight: 700;
}

.place-sub {
  margin: 3px 0 0;
  font-size: 12px;
  color: var(--color-text-hint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.hint-text {
  margin: 8px 0 0;
}

.bottom-bar {
  position: fixed;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  padding: 12px 18px calc(12px + env(safe-area-inset-bottom));
  background: var(--color-background);
  border-top: 1px solid var(--color-divider);
  z-index: 40;
}

textarea.text-field {
  resize: vertical;
}
</style>
