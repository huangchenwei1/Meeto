<script setup lang="ts">
import { computed, ref } from 'vue';

import { strings } from '@/constants/strings';

/**
 * The platform meeting-time picker: day chips for the coming week plus
 * half-hour start slots inside the host working window (09:00-22:00 with
 * the standard 2h activity, so starts run 09:00-20:00). Out-of-hours
 * times simply do not exist as options — a safety rule, mirrored by the
 * server-side guard. Callers can narrow the window further (e.g. a pitch
 * that only offers evenings) via [startHour]/[endHour].
 */
const props = withDefaults(
  defineProps<{
    /** Earliest pickable start hour, Manila local. */
    startHour?: number;
    /** Latest pickable start hour, Manila local (inclusive). */
    endHour?: number;
  }>(),
  { startHour: 9, endHour: 20 },
);

/** The picked start time; null until the user picks a slot. */
const model = defineModel<Date | null>({ default: null });

const SLOT_STEP_MINUTES = 30;
const DAYS_SHOWN = 7;
/** Minimum lead before a slot today becomes pickable. */
const MIN_LEAD_MS = 60 * 60 * 1000;

const openMinutes = computed(() => props.startHour * 60);
const lastStartMinutes = computed(() => props.endHour * 60);

interface DayOption {
  key: string;
  startOfDay: Date;
  name: string;
  dateLabel: string;
}

interface SlotOption {
  key: string;
  at: Date;
  label: string;
  disabled: boolean;
}

const pad2 = (n: number) => String(n).padStart(2, '0');

const dayOptions = computed<DayOption[]>(() => {
  const now = new Date();
  const days: DayOption[] = [];
  for (let i = 0; i < DAYS_SHOWN; i += 1) {
    const startOfDay = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate() + i,
    );
    // Drop days whose slots are all gone (only today can be affected).
    const lastStartAt = new Date(
      startOfDay.getTime() + lastStartMinutes.value * 60000,
    );
    if (lastStartAt.getTime() < Date.now() + MIN_LEAD_MS) continue;
    const name =
      i === 0
        ? strings.todayLabel
        : i === 1
          ? strings.tomorrowLabel
          : strings.weekdayLabel(startOfDay.getDay());
    days.push({
      key: startOfDay.toISOString(),
      startOfDay,
      name,
      dateLabel: `${startOfDay.getMonth() + 1}/${startOfDay.getDate()}`,
    });
  }
  return days;
});

const selectedDayKey = ref('');

const selectedDay = computed(
  () =>
    dayOptions.value.find((d) => d.key === selectedDayKey.value) ??
    dayOptions.value[0],
);

const slotOptions = computed<SlotOption[]>(() => {
  const day = selectedDay.value;
  if (!day) return [];
  const slots: SlotOption[] = [];
  for (
    let minutes = openMinutes.value;
    minutes <= lastStartMinutes.value;
    minutes += SLOT_STEP_MINUTES
  ) {
    const at = new Date(day.startOfDay.getTime() + minutes * 60000);
    slots.push({
      key: at.toISOString(),
      at,
      label: `${pad2(at.getHours())}:${pad2(at.getMinutes())}`,
      disabled: at.getTime() < Date.now() + MIN_LEAD_MS,
    });
  }
  return slots;
});

function pickDay(day: DayOption): void {
  selectedDayKey.value = day.key;
  // A slot belongs to one day: switching days clears the pick.
  model.value = null;
}

function pickSlot(slot: SlotOption): void {
  model.value = slot.at;
}

const selectedSlotKey = computed(() => model.value?.toISOString() ?? '');
</script>

<template>
  <div>
    <div class="day-scroll">
      <button
        v-for="d in dayOptions"
        :key="d.key"
        class="day-chip"
        :class="{ selected: selectedDay?.key === d.key }"
        @click="pickDay(d)"
      >
        <span class="day-chip-name">{{ d.name }}</span>
        <span class="day-chip-date">{{ d.dateLabel }}</span>
      </button>
    </div>
    <div class="slot-grid">
      <button
        v-for="s in slotOptions"
        :key="s.key"
        class="slot-chip"
        :class="{ selected: selectedSlotKey === s.key }"
        :disabled="s.disabled"
        @click="pickSlot(s)"
      >
        {{ s.label }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.day-scroll {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  padding-bottom: 4px;
  scrollbar-width: none;
}

.day-scroll::-webkit-scrollbar {
  display: none;
}

.day-chip {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 8px 14px;
  border-radius: 12px;
  border: 1px solid var(--color-border);
  background: var(--color-background);
}

.day-chip.selected {
  background: var(--color-accent-soft);
  border-color: var(--color-accent);
  color: var(--color-accent);
}

.day-chip-name {
  font-size: 13px;
  font-weight: 700;
}

.day-chip-date {
  font-size: 11px;
  opacity: 0.7;
}

.slot-grid {
  margin-top: 10px;
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 8px;
}

.slot-chip {
  padding: 9px 0;
  border-radius: 10px;
  border: 1px solid var(--color-border);
  background: var(--color-background);
  font-size: 13px;
  font-weight: 600;
  text-align: center;
}

.slot-chip.selected {
  background: var(--color-accent-soft);
  border-color: var(--color-accent);
  color: var(--color-accent);
}

.slot-chip:disabled {
  color: var(--color-text-hint);
  background: var(--color-surface);
  border-color: transparent;
}
</style>
