<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { register } from '@/api/auth';
import { resolveMediaUrl, uploadImage } from '@/api/client';
import { fetchRawMe, updateProfile } from '@/api/users';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { useSessionStore } from '@/stores/session';
import { showToast } from '@/utils/toast';

const MAX_WALL_PHOTOS = 3;
const MIN_HEIGHT = 140;
const MAX_HEIGHT = 210;
const MIN_WEIGHT = 35;
const MAX_WEIGHT = 120;
const STEP_COUNT = 10;

const route = useRoute();
const router = useRouter();
const session = useSessionStore();

const isEditing = computed(() => route.query.mode === 'edit');
const registrationToken = (route.query.registrationToken as string) ?? '';

const step = ref(0);
const busy = ref(false);
const registered = ref(false);

const role = ref<string | null>(null);
const gender = ref<string | null>(null);
const name = ref('');
const maxYear = new Date().getFullYear() - 18;
const years = Array.from({ length: 63 }, (_, i) => maxYear - i);
const birthYear = ref(maxYear - 7); // ~25 years old
const birthMonth = ref(1);
const heightCm = ref<number | null>(null);
const weightKg = ref<number | null>(null);
const country = ref<string | null>(null);
const city = ref<string | null>(null);
const education = ref<string | null>(null);
const job = ref<string | null>(null);
const tags = ref<Set<string>>(new Set());
const bio = ref('');
const avatarUrl = ref<string | null>(null); // root-relative, as stored
const photoUrls = ref<string[]>([]);

const heights = Array.from(
  { length: MAX_HEIGHT - MIN_HEIGHT + 1 },
  (_, i) => MIN_HEIGHT + i,
);
const weights = Array.from(
  { length: MAX_WEIGHT - MIN_WEIGHT + 1 },
  (_, i) => MIN_WEIGHT + i,
);

const citiesForCountry = computed(() => {
  const entry = strings.countryCities.find(([c]) => c === country.value);
  return entry ? entry[1] : [];
});

const isLastStep = computed(() => step.value === STEP_COUNT - 1);
/** Height/weight, location, work, interests and bio are skippable. */
const canSkip = computed(() => step.value >= 4 && step.value <= 8);
const canGoBack = computed(
  () => step.value > 0 && !(registered.value && step.value <= 3),
);

onMounted(async () => {
  if (!isEditing.value) return;
  registered.value = true;
  try {
    const user = await fetchRawMe();
    role.value = (user.role as string) ?? null;
    const avatar = (user.avatarUrl as string) ?? '';
    avatarUrl.value = avatar.length > 0 ? avatar : null;
    name.value = (user.name as string) ?? '';
    bio.value = (user.bio as string) ?? '';
    heightCm.value = (user.heightCm as number) ?? null;
    weightKg.value = (user.weightKg as number) ?? null;
    country.value = ((user.country as string) ?? '') || null;
    city.value = ((user.city as string) ?? '') || null;
    education.value = ((user.education as string) ?? '') || null;
    job.value = ((user.job as string) ?? '') || null;
    tags.value = new Set((user.tags as string[]) ?? []);
    photoUrls.value = [...((user.photos as string[]) ?? [])];
  } catch {
    // Keep the empty form; the user can still fill and save.
  }
});

function toggleTag(tag: string): void {
  if (tags.value.has(tag)) {
    tags.value.delete(tag);
  } else {
    tags.value.add(tag);
  }
  tags.value = new Set(tags.value);
}

function pickCountry(value: string): void {
  if (country.value !== value) {
    country.value = value;
    city.value = null;
  }
}

async function pickFile(): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'image/*';
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.oncancel = () => resolve(null);
    input.click();
  });
}

async function pickAndUpload(): Promise<string | null> {
  const file = await pickFile();
  if (!file) return null;
  try {
    return await uploadImage(file);
  } catch {
    showToast(strings.setupUploadFailed);
    return null;
  }
}

async function pickAvatar(): Promise<void> {
  const url = await pickAndUpload();
  if (!url) return;
  if (isEditing.value && !(await patchProfile({ avatarUrl: url }))) return;
  avatarUrl.value = url;
}

async function addWallPhoto(): Promise<void> {
  if (photoUrls.value.length >= MAX_WALL_PHOTOS) return;
  const url = await pickAndUpload();
  if (!url) return;
  const next = [...photoUrls.value, url];
  if (isEditing.value && !(await patchProfile({ photos: next }))) return;
  photoUrls.value = next;
}

async function removeWallPhoto(index: number): Promise<void> {
  const next = photoUrls.value.filter((_, i) => i !== index);
  if (isEditing.value && !(await patchProfile({ photos: next }))) return;
  photoUrls.value = next;
}

/** Sends a partial update and refreshes the session copy of the user. */
async function patchProfile(patch: Record<string, unknown>): Promise<boolean> {
  busy.value = true;
  try {
    applySessionUser(await updateProfile(patch));
    return true;
  } catch {
    showToast(strings.errorNetwork);
    return false;
  } finally {
    busy.value = false;
  }
}

function applySessionUser(user: Record<string, unknown>): void {
  session.setUser({
    id: user.id as string,
    name: user.name as string,
    avatarUrl: (user.avatarUrl as string) ?? '',
    meta: (user.meta as string) ?? '',
    gender: (user.gender as string) ?? session.user?.gender ?? 'FEMALE',
    role: (user.role as string) ?? session.user?.role ?? 'USER',
  });
}

async function doRegister(): Promise<boolean> {
  busy.value = true;
  try {
    await register({
      registrationToken,
      name: name.value.trim(),
      gender: gender.value!,
      role: role.value!,
    });
    registered.value = true;
    return true;
  } catch {
    showToast(strings.errorNetwork);
    return false;
  } finally {
    busy.value = false;
  }
}

/** Final submit of the registration wizard (edit mode saves per field). */
async function save(): Promise<void> {
  if (!avatarUrl.value) {
    // The avatar is mandatory: it is the reference photo real-person
    // verification matches the liveness selfie against.
    showToast(strings.setupAvatarRequired);
    return;
  }
  const body: Record<string, unknown> = {
    avatarUrl: avatarUrl.value,
    birthDate: new Date(
      Date.UTC(birthYear.value, birthMonth.value - 1),
    ).toISOString(),
  };
  if (heightCm.value != null) body.heightCm = heightCm.value;
  if (weightKg.value != null) body.weightKg = weightKg.value;
  if (country.value) body.country = country.value;
  if (city.value) body.city = city.value;
  if (education.value) body.education = education.value;
  if (job.value) body.job = job.value;
  if (tags.value.size > 0) body.tags = [...tags.value];
  if (bio.value.trim().length > 0) body.bio = bio.value.trim();
  if (photoUrls.value.length > 0) body.photos = photoUrls.value;
  if (await patchProfile(body)) {
    await router.replace('/hall');
  }
}

// --- Edit mode: settings-list rows, each opening a one-field sheet. ---

type SheetKind =
  | 'name'
  | 'body'
  | 'location'
  | 'education'
  | 'job'
  | 'tags'
  | 'bio';

const activeSheet = ref<SheetKind | null>(null);
const draftName = ref('');
const draftHeight = ref<number | null>(null);
const draftWeight = ref<number | null>(null);
const draftCountry = ref<string | null>(null);
const draftCity = ref<string | null>(null);
const draftEducation = ref<string | null>(null);
const draftJob = ref<string | null>(null);
const draftTags = ref<Set<string>>(new Set());
const draftBio = ref('');

const draftCities = computed(() => {
  const entry = strings.countryCities.find(([c]) => c === draftCountry.value);
  return entry ? entry[1] : [];
});

const sheetTitles: Record<SheetKind, string> = {
  name: strings.editNameLabel,
  body: strings.setupStepBodyTitle,
  location: strings.editLocationLabel,
  education: strings.setupEducationLabel,
  job: strings.setupJobLabel,
  tags: strings.setupTagsLabel,
  bio: strings.setupBioLabel,
};

const editRows = computed<Array<{ kind: SheetKind; label: string; value: string }>>(
  () => [
    { kind: 'name', label: strings.editNameLabel, value: name.value },
    {
      kind: 'body',
      label: strings.setupStepBodyTitle,
      value: [
        heightCm.value != null ? `${heightCm.value} cm` : null,
        weightKg.value != null ? `${weightKg.value} kg` : null,
      ]
        .filter((p) => p !== null)
        .join(' / '),
    },
    {
      kind: 'location',
      label: strings.editLocationLabel,
      value: [country.value, city.value].filter((p) => p).join(' · '),
    },
    {
      kind: 'education',
      label: strings.setupEducationLabel,
      value: education.value ?? '',
    },
    { kind: 'job', label: strings.setupJobLabel, value: job.value ?? '' },
    {
      kind: 'tags',
      label: strings.setupTagsLabel,
      value: [...tags.value].join(' · '),
    },
    { kind: 'bio', label: strings.setupBioLabel, value: bio.value.trim() },
  ],
);

function openSheet(kind: SheetKind): void {
  draftName.value = name.value;
  draftHeight.value = heightCm.value;
  draftWeight.value = weightKg.value;
  draftCountry.value = country.value;
  draftCity.value = city.value;
  draftEducation.value = education.value;
  draftJob.value = job.value;
  draftTags.value = new Set(tags.value);
  draftBio.value = bio.value;
  activeSheet.value = kind;
}

function pickDraftCountry(value: string): void {
  if (draftCountry.value !== value) {
    draftCountry.value = value;
    draftCity.value = null;
  }
}

function toggleDraftTag(tag: string): void {
  if (draftTags.value.has(tag)) {
    draftTags.value.delete(tag);
  } else {
    draftTags.value.add(tag);
  }
  draftTags.value = new Set(draftTags.value);
}

async function confirmSheet(): Promise<void> {
  const kind = activeSheet.value;
  if (!kind || busy.value) return;
  const patch: Record<string, unknown> = {};
  let apply = (): void => {};
  switch (kind) {
    case 'name': {
      const trimmed = draftName.value.trim();
      if (trimmed.length === 0) return showToast(strings.nameRequiredHint);
      patch.name = trimmed;
      apply = () => (name.value = trimmed);
      break;
    }
    case 'body':
      if (draftHeight.value != null) patch.heightCm = draftHeight.value;
      if (draftWeight.value != null) patch.weightKg = draftWeight.value;
      apply = () => {
        if (draftHeight.value != null) heightCm.value = draftHeight.value;
        if (draftWeight.value != null) weightKg.value = draftWeight.value;
      };
      break;
    case 'location':
      if (draftCountry.value) patch.country = draftCountry.value;
      if (draftCity.value) patch.city = draftCity.value;
      apply = () => {
        if (draftCountry.value) country.value = draftCountry.value;
        if (draftCity.value) city.value = draftCity.value;
      };
      break;
    case 'education':
      if (draftEducation.value) patch.education = draftEducation.value;
      apply = () => (education.value = draftEducation.value);
      break;
    case 'job':
      if (draftJob.value) patch.job = draftJob.value;
      apply = () => (job.value = draftJob.value);
      break;
    case 'tags':
      patch.tags = [...draftTags.value];
      apply = () => (tags.value = new Set(draftTags.value));
      break;
    case 'bio':
      patch.bio = draftBio.value.trim();
      apply = () => (bio.value = draftBio.value.trim());
      break;
  }
  if (Object.keys(patch).length > 0) {
    if (!(await patchProfile(patch))) return;
    apply();
  }
  activeSheet.value = null;
}

async function next(): Promise<void> {
  switch (step.value) {
    case 0:
      if (!role.value) return showToast(strings.roleRequiredHint);
      break;
    case 1:
      if (!gender.value) return showToast(strings.genderRequiredHint);
      break;
    case 2:
      if (name.value.trim().length === 0) {
        return showToast(strings.nameRequiredHint);
      }
      if (!registered.value && !(await doRegister())) return;
      break;
    case 4:
      heightCm.value ??= 165;
      weightKg.value ??= 55;
      break;
  }
  if (isLastStep.value) {
    await save();
  } else {
    step.value += 1;
  }
}

const stepMeta: Array<{ title: string; sub: string }> = [
  { title: strings.setupStepRoleTitle, sub: strings.setupStepRoleSub },
  { title: strings.setupStepGenderTitle, sub: strings.setupStepGenderSub },
  { title: strings.setupStepNameTitle, sub: strings.setupStepNameSub },
  { title: strings.setupStepBirthTitle, sub: strings.setupStepBirthSub },
  { title: strings.setupStepBodyTitle, sub: strings.setupStepBodySub },
  { title: strings.setupStepLocationTitle, sub: strings.setupStepLocationSub },
  { title: strings.setupStepWorkTitle, sub: strings.setupStepWorkSub },
  { title: strings.setupStepTagsTitle, sub: strings.setupStepTagsSub },
  { title: strings.setupStepBioTitle, sub: strings.setupStepBioSub },
  { title: strings.setupStepPhotosTitle, sub: strings.setupStepPhotosSub },
];
</script>

<template>
  <!-- Edit mode: a settings list; each row opens a one-field bottom sheet. -->
  <div v-if="isEditing" class="setup-page">
    <PageHeader :title="strings.menuEditProfile" />
    <div class="content">
      <section class="field-block">
        <p class="field-label">{{ strings.editPhotosLabel }}</p>
        <div class="photo-row">
          <button class="photo-tile" :disabled="busy" @click="pickAvatar">
            <img v-if="avatarUrl" :src="resolveMediaUrl(avatarUrl)" alt="" />
            <span v-else class="plus">+</span>
            <span class="badge">{{ strings.setupMainPhotoBadge }}</span>
          </button>
          <div v-for="i in MAX_WALL_PHOTOS" :key="i" class="photo-tile-wrap">
            <button
              class="photo-tile"
              :disabled="busy || i - 1 > photoUrls.length"
              @click="i - 1 < photoUrls.length ? undefined : addWallPhoto()"
            >
              <img
                v-if="i - 1 < photoUrls.length"
                :src="resolveMediaUrl(photoUrls[i - 1])"
                alt=""
              />
              <span v-else class="plus">+</span>
            </button>
            <button
              v-if="i - 1 < photoUrls.length"
              class="remove-photo"
              @click="removeWallPhoto(i - 1)"
            >
              ×
            </button>
          </div>
        </div>
      </section>

      <section class="edit-list">
        <button
          v-for="row in editRows"
          :key="row.kind"
          class="edit-row"
          @click="openSheet(row.kind)"
        >
          <span class="row-label">{{ row.label }}</span>
          <span class="row-value" :class="{ empty: row.value.length === 0 }">
            {{ row.value.length > 0 ? row.value : strings.editNotSet }}
          </span>
          <span class="row-arrow">›</span>
        </button>
      </section>
    </div>

    <Teleport to="body">
      <div
        v-if="activeSheet"
        class="sheet-mask"
        @click.self="activeSheet = null"
      >
        <div class="sheet">
        <p class="sheet-title">{{ sheetTitles[activeSheet] }}</p>

        <input
          v-if="activeSheet === 'name'"
          v-model="draftName"
          class="text-field"
          maxlength="40"
          :placeholder="strings.setupNameHint"
        />

        <div v-else-if="activeSheet === 'body'" class="select-row">
          <select v-model.number="draftHeight" class="text-field">
            <option :value="null">{{ strings.setupHeightLabel }}</option>
            <option v-for="h in heights" :key="h" :value="h">{{ h }} cm</option>
          </select>
          <select v-model.number="draftWeight" class="text-field">
            <option :value="null">{{ strings.setupWeightLabel }}</option>
            <option v-for="w in weights" :key="w" :value="w">{{ w }} kg</option>
          </select>
        </div>

        <template v-else-if="activeSheet === 'location'">
          <div class="chip-wrap">
            <button
              v-for="[c] in strings.countryCities"
              :key="c"
              class="chip"
              :class="{ selected: draftCountry === c }"
              @click="pickDraftCountry(c)"
            >
              {{ c }}
            </button>
          </div>
          <div v-if="draftCities.length > 0" class="chip-wrap">
            <button
              v-for="c in draftCities"
              :key="c"
              class="chip"
              :class="{ selected: draftCity === c }"
              @click="draftCity = c"
            >
              {{ c }}
            </button>
          </div>
        </template>

        <div v-else-if="activeSheet === 'education'" class="chip-wrap">
          <button
            v-for="option in strings.educationOptions"
            :key="option"
            class="chip"
            :class="{ selected: draftEducation === option }"
            @click="draftEducation = option"
          >
            {{ option }}
          </button>
        </div>

        <div v-else-if="activeSheet === 'job'" class="chip-wrap">
          <button
            v-for="option in strings.jobOptions"
            :key="option"
            class="chip"
            :class="{ selected: draftJob === option }"
            @click="draftJob = option"
          >
            {{ option }}
          </button>
        </div>

        <div v-else-if="activeSheet === 'tags'" class="chip-wrap">
          <button
            v-for="tag in strings.setupTagOptions"
            :key="tag"
            class="chip"
            :class="{ selected: draftTags.has(tag) }"
            @click="toggleDraftTag(tag)"
          >
            {{ tag }}
          </button>
        </div>

        <textarea
          v-else-if="activeSheet === 'bio'"
          v-model="draftBio"
          class="text-field"
          rows="5"
          maxlength="600"
          :placeholder="strings.setupBioHint"
        ></textarea>

          <button
            class="btn-primary sheet-cta"
            :disabled="busy"
            @click="confirmSheet"
          >
            {{ busy ? '...' : strings.setupSave }}
          </button>
        </div>
      </div>
    </Teleport>
  </div>

  <!-- Registration wizard: one light topic per screen. -->
  <div v-else class="setup-page">
    <div class="wizard-top">
      <button v-if="canGoBack" class="nav-btn" :disabled="busy" @click="step -= 1">
        ‹
      </button>
      <div v-else class="nav-btn"></div>
      <div class="progress">
        <div
          class="progress-fill"
          :style="{ width: `${((step + 1) / STEP_COUNT) * 100}%` }"
        ></div>
      </div>
      <button v-if="canSkip" class="nav-btn skip" :disabled="busy" @click="step += 1">
        {{ strings.setupStepSkip }}
      </button>
      <div v-else class="nav-btn"></div>
    </div>

    <div class="content wizard-body">
      <h2 class="step-title">{{ stepMeta[step].title }}</h2>
      <p class="step-sub">{{ stepMeta[step].sub }}</p>

      <!-- Step 0: role -->
      <div v-if="step === 0" class="card-options">
        <button
          class="option-card"
          :class="{ selected: role === 'USER' }"
          @click="role = 'USER'"
        >
          <span class="option-title">{{ strings.roleUserLabel }}</span>
          <span class="option-sub">{{ strings.roleUserSub }}</span>
        </button>
        <button
          class="option-card"
          :class="{ selected: role === 'HOST' }"
          @click="role = 'HOST'"
        >
          <span class="option-title">{{ strings.roleHostLabel }}</span>
          <span class="option-sub">{{ strings.roleHostSub }}</span>
        </button>
      </div>

      <!-- Step 1: gender -->
      <div v-else-if="step === 1" class="card-options">
        <button
          class="option-card"
          :class="{ selected: gender === 'FEMALE' }"
          @click="gender = 'FEMALE'"
        >
          <span class="option-title">{{ strings.genderFemaleLabel }}</span>
        </button>
        <button
          class="option-card"
          :class="{ selected: gender === 'MALE' }"
          @click="gender = 'MALE'"
        >
          <span class="option-title">{{ strings.genderMaleLabel }}</span>
        </button>
      </div>

      <!-- Step 2: name -->
      <input
        v-else-if="step === 2"
        v-model="name"
        class="text-field name-field"
        maxlength="40"
        :placeholder="strings.setupNameHint"
      />

      <!-- Step 3: birth -->
      <div v-else-if="step === 3" class="select-row">
        <label class="select-col">
          <span class="field-label">{{ strings.setupBirthYearLabel }}</span>
          <select v-model.number="birthYear" class="text-field">
            <option v-for="y in years" :key="y" :value="y">{{ y }}</option>
          </select>
        </label>
        <label class="select-col">
          <span class="field-label">{{ strings.setupBirthMonthLabel }}</span>
          <select v-model.number="birthMonth" class="text-field">
            <option v-for="m in 12" :key="m" :value="m">{{ m }}</option>
          </select>
        </label>
      </div>

      <!-- Step 4: body -->
      <div v-else-if="step === 4" class="select-row">
        <label class="select-col">
          <span class="field-label">{{ strings.setupHeightLabel }}</span>
          <select v-model.number="heightCm" class="text-field">
            <option :value="null">-</option>
            <option v-for="h in heights" :key="h" :value="h">{{ h }} cm</option>
          </select>
        </label>
        <label class="select-col">
          <span class="field-label">{{ strings.setupWeightLabel }}</span>
          <select v-model.number="weightKg" class="text-field">
            <option :value="null">-</option>
            <option v-for="w in weights" :key="w" :value="w">{{ w }} kg</option>
          </select>
        </label>
      </div>

      <!-- Step 5: location -->
      <template v-else-if="step === 5">
        <p class="field-label">{{ strings.setupCountryLabel }}</p>
        <div class="chip-wrap">
          <button
            v-for="[c] in strings.countryCities"
            :key="c"
            class="chip"
            :class="{ selected: country === c }"
            @click="pickCountry(c)"
          >
            {{ c }}
          </button>
        </div>
        <template v-if="citiesForCountry.length > 0">
          <p class="field-label">{{ strings.setupCityLabel }}</p>
          <div class="chip-wrap">
            <button
              v-for="c in citiesForCountry"
              :key="c"
              class="chip"
              :class="{ selected: city === c }"
              @click="city = c"
            >
              {{ c }}
            </button>
          </div>
        </template>
      </template>

      <!-- Step 6: work -->
      <template v-else-if="step === 6">
        <p class="field-label">{{ strings.setupEducationLabel }}</p>
        <div class="chip-wrap">
          <button
            v-for="option in strings.educationOptions"
            :key="option"
            class="chip"
            :class="{ selected: education === option }"
            @click="education = education === option ? null : option"
          >
            {{ option }}
          </button>
        </div>
        <p class="field-label">{{ strings.setupJobLabel }}</p>
        <div class="chip-wrap">
          <button
            v-for="option in strings.jobOptions"
            :key="option"
            class="chip"
            :class="{ selected: job === option }"
            @click="job = job === option ? null : option"
          >
            {{ option }}
          </button>
        </div>
      </template>

      <!-- Step 7: tags -->
      <div v-else-if="step === 7" class="chip-wrap">
        <button
          v-for="tag in strings.setupTagOptions"
          :key="tag"
          class="chip"
          :class="{ selected: tags.has(tag) }"
          @click="toggleTag(tag)"
        >
          {{ tag }}
        </button>
      </div>

      <!-- Step 8: bio -->
      <textarea
        v-else-if="step === 8"
        v-model="bio"
        class="text-field"
        rows="5"
        maxlength="600"
        :placeholder="strings.setupBioHint"
      ></textarea>

      <!-- Step 9: photos -->
      <div v-else-if="step === 9" class="photo-grid">
        <button class="photo-tile" @click="pickAvatar">
          <img v-if="avatarUrl" :src="resolveMediaUrl(avatarUrl)" alt="" />
          <span v-else class="plus">+</span>
          <span class="badge">{{ strings.setupMainPhotoBadge }}</span>
        </button>
        <div v-for="i in MAX_WALL_PHOTOS" :key="i" class="photo-tile-wrap">
          <button
            class="photo-tile"
            :disabled="i - 1 > photoUrls.length"
            @click="i - 1 < photoUrls.length ? undefined : addWallPhoto()"
          >
            <img
              v-if="i - 1 < photoUrls.length"
              :src="resolveMediaUrl(photoUrls[i - 1])"
              alt=""
            />
            <span v-else class="plus">+</span>
          </button>
          <button
            v-if="i - 1 < photoUrls.length"
            class="remove-photo"
            @click="removeWallPhoto(i - 1)"
          >
            ×
          </button>
        </div>
      </div>
    </div>

    <div class="wizard-footer">
      <button class="btn-primary" :disabled="busy" @click="next">
        {{ busy ? '...' : isLastStep ? strings.setupFinish : strings.setupNext }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.setup-page {
  min-height: 100dvh;
  background: var(--color-background);
  display: flex;
  flex-direction: column;
}

.content {
  padding: 18px 24px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.wizard-body {
  flex: 1;
  overflow-y: auto;
}

.wizard-top {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px 0;
}

.nav-btn {
  width: 56px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-text-secondary);
  font-size: 22px;
}

.nav-btn.skip {
  font-size: 13px;
}

.progress {
  flex: 1;
  height: 4px;
  border-radius: 999px;
  background: var(--color-surface);
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: var(--color-dark-card);
  border-radius: 999px;
  transition: width 0.25s ease;
}

.step-title {
  font-size: 26px;
  font-weight: 800;
  margin: 0;
}

.step-sub {
  font-size: 14px;
  color: var(--color-text-secondary);
  margin: 0 0 12px;
}

.card-options {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.option-card {
  text-align: left;
  padding: 20px;
  border-radius: 18px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  display: flex;
  flex-direction: column;
  gap: 3px;
}

.option-card.selected {
  background: var(--color-dark-card);
  border-color: var(--color-dark-card);
}

.option-title {
  font-size: 17px;
  font-weight: 700;
}

.option-card.selected .option-title {
  color: var(--color-on-dark-primary);
}

.option-sub {
  font-size: 12.5px;
  color: var(--color-text-secondary);
  line-height: 1.35;
}

.option-card.selected .option-sub {
  color: var(--color-on-dark-secondary);
}

.name-field {
  font-size: 22px;
  font-weight: 700;
}

.select-row {
  display: flex;
  gap: 12px;
}

.select-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.field-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--color-text-secondary);
  margin: 0;
}

.chip-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.field-block {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.photo-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.photo-row {
  display: flex;
  gap: 10px;
}

.photo-row .photo-tile,
.photo-row .photo-tile-wrap {
  flex: 1;
  aspect-ratio: 3 / 4;
}

.photo-tile-wrap {
  position: relative;
}

.photo-tile-wrap .photo-tile {
  width: 100%;
  height: 100%;
}

.photo-grid .photo-tile,
.photo-grid .photo-tile-wrap {
  aspect-ratio: 0.92;
}

.photo-tile {
  position: relative;
  border-radius: 16px;
  border: 1px solid var(--color-border);
  background: var(--color-surface);
  overflow: hidden;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
}

.photo-tile img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.plus {
  font-size: 28px;
  color: var(--color-text-hint);
}

.badge {
  position: absolute;
  left: 8px;
  bottom: 8px;
  padding: 3px 8px;
  border-radius: 999px;
  background: var(--color-dark-card);
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  z-index: 1;
}

.remove-photo {
  position: absolute;
  right: 6px;
  top: 6px;
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: rgb(0 0 0 / 55%);
  color: #fff;
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1;
}

.wizard-footer {
  padding: 8px 24px 16px;
}

textarea.text-field {
  resize: vertical;
}

.edit-list {
  background: var(--color-surface);
  border-radius: 16px;
  overflow: hidden;
}

.edit-row {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 15px 16px;
  text-align: left;
}

.edit-row + .edit-row {
  border-top: 1px solid var(--color-border);
}

.row-label {
  font-size: 14.5px;
  font-weight: 600;
  flex-shrink: 0;
}

.row-value {
  flex: 1;
  min-width: 0;
  text-align: right;
  font-size: 13.5px;
  color: var(--color-text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.row-value.empty {
  color: var(--color-text-hint);
}

.row-arrow {
  color: var(--color-text-hint);
  font-size: 17px;
  flex-shrink: 0;
}

.sheet-mask {
  position: fixed;
  inset: 0;
  background: rgb(0 0 0 / 40%);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  z-index: 60;
}

.sheet {
  width: 100%;
  max-width: 480px;
  max-height: 80dvh;
  overflow-y: auto;
  background: var(--color-background);
  border-radius: 20px 20px 0 0;
  padding: 24px 24px calc(24px + env(safe-area-inset-bottom));
  display: flex;
  flex-direction: column;
  gap: 14px;
}

/* The sheet is a capped flex column: without this, overflowing content
   squashes the children (the save button collapses) instead of scrolling. */
.sheet > * {
  flex-shrink: 0;
}

.sheet-title {
  margin: 0;
  font-size: 18px;
  font-weight: 800;
}

.sheet-cta {
  margin-top: 6px;
}
</style>
