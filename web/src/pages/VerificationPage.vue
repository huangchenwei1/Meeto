<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { ApiError, uploadImage } from '@/api/client';
import { fetchCurrentUser, submitVerification } from '@/api/users';
import PageHeader from '@/components/PageHeader.vue';
import { strings } from '@/constants/strings';
import { showToast } from '@/utils/toast';

const router = useRouter();

const avatarUrl = ref('');
const loading = ref(true);
const busy = ref(false);

// ---- Liveness overlay state ----
// Web stand-in for a vendor liveness SDK: live front-camera preview in an
// oval viewport, guided prompts with screen color flashes, then a frame
// grab that the server matches against the profile photo. Swapping in a
// real SDK later only replaces runCheck(); the page shell stays.
type LivenessPhase = 'preview' | 'checking' | 'uploading';

const livenessOpen = ref(false);
const phase = ref<LivenessPhase>('preview');
const stepText = ref('');
const videoEl = ref<HTMLVideoElement | null>(null);

let stream: MediaStream | null = null;

const CHECK_STEPS = [
  strings.livenessStepHold,
  strings.livenessStepBlink,
  strings.livenessStepTurn,
];
const STEP_MS = 1700;

onMounted(async () => {
  try {
    avatarUrl.value = (await fetchCurrentUser()).avatarUrl;
  } finally {
    loading.value = false;
  }
});

onBeforeUnmount(stopCamera);

function stopCamera(): void {
  stream?.getTracks().forEach((track) => track.stop());
  stream = null;
}

async function startVerification(): Promise<void> {
  livenessOpen.value = true;
  phase.value = 'preview';
  await nextTick();
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'user' },
      audio: false,
    });
    if (videoEl.value) {
      videoEl.value.srcObject = stream;
      await videoEl.value.play();
    }
  } catch {
    // No camera or permission denied: fall back to the native capture
    // input so desktop and restricted browsers can still verify.
    livenessOpen.value = false;
    showToast(strings.livenessCameraError);
    pickFallbackPhoto();
  }
}

function closeLiveness(): void {
  stopCamera();
  livenessOpen.value = false;
  phase.value = 'preview';
}

function pickFallbackPhoto(): void {
  const picker = document.createElement('input');
  picker.type = 'file';
  picker.accept = 'image/*';
  picker.capture = 'user';
  picker.onchange = () => {
    const file = picker.files?.[0];
    if (file) void submit(file);
  };
  picker.click();
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function runCheck(): Promise<void> {
  if (phase.value !== 'preview') return;
  phase.value = 'checking';
  for (const step of CHECK_STEPS) {
    stepText.value = step;
    await sleep(STEP_MS);
    if (!livenessOpen.value) return; // user closed mid-check
  }
  const file = captureFrame();
  if (!file) {
    closeLiveness();
    showToast(strings.setupUploadFailed);
    return;
  }
  phase.value = 'uploading';
  stepText.value = strings.livenessUploading;
  await submit(await file);
}

function captureFrame(): Promise<File> | null {
  const video = videoEl.value;
  if (!video || video.videoWidth === 0) return null;
  const canvas = document.createElement('canvas');
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  canvas.getContext('2d')?.drawImage(video, 0, 0);
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => {
      if (!blob) return reject(new Error('capture failed'));
      resolve(new File([blob], 'liveness.jpg', { type: 'image/jpeg' }));
    }, 'image/jpeg', 0.9);
  });
}

async function submit(file: File): Promise<void> {
  busy.value = true;
  try {
    const selfieUrl = await uploadImage(file);
    await submitVerification(selfieUrl);
    closeLiveness();
    showToast(strings.verifySuccess);
    router.back();
  } catch (error) {
    showToast(
      error instanceof ApiError ? error.message : strings.setupUploadFailed,
    );
    if (livenessOpen.value) phase.value = 'preview';
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <div class="verify-page">
    <PageHeader :title="strings.verifyTitle" />

    <div v-if="loading" class="loading">…</div>

    <div v-else class="content">
      <div class="shield">🛡️</div>
      <p class="sub">{{ strings.verifySub }}</p>

      <template v-if="avatarUrl">
        <img class="reference" :src="avatarUrl" alt="" />
        <p class="reference-label">{{ strings.verifyYourPhoto }}</p>
        <button
          class="btn-primary cta"
          :disabled="busy"
          @click="startVerification"
        >
          {{ busy ? '…' : strings.verifyStart }}
        </button>
      </template>

      <template v-else>
        <div class="no-avatar-card">{{ strings.verifyNoAvatar }}</div>
        <button class="btn-primary cta" @click="router.push('/setup?mode=edit')">
          {{ strings.verifyGoSetAvatar }}
        </button>
      </template>
    </div>

    <div
      v-if="livenessOpen"
      class="liveness"
      :class="{ flashing: phase === 'checking' }"
    >
      <button class="liveness-close" @click="closeLiveness">✕</button>

      <div class="warn">
        <span class="warn-icon">⚠️</span>
        <div>
          <p class="warn-title">{{ strings.livenessWarnTitle }}</p>
          <p class="warn-body">{{ strings.livenessWarnBody }}</p>
        </div>
      </div>

      <p class="guide">
        {{ phase === 'preview' ? strings.livenessGuide : stepText }}
      </p>

      <div class="oval">
        <video ref="videoEl" class="camera" autoplay playsinline muted />
      </div>

      <button
        class="btn-primary liveness-cta"
        :disabled="phase !== 'preview'"
        @click="runCheck"
      >
        {{ phase === 'preview' ? strings.livenessStart : '…' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.verify-page {
  min-height: 100dvh;
  background: var(--color-background);
}

.loading {
  padding: 80px 0 0;
  text-align: center;
  color: var(--color-text-secondary);
}

.content {
  padding: 24px;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.shield {
  font-size: 48px;
}

.sub {
  margin: 18px 0 28px;
  font-size: 14px;
  line-height: 1.6;
  color: var(--color-text-secondary);
  text-align: center;
}

.reference {
  width: 140px;
  height: 140px;
  border-radius: 20px;
  object-fit: cover;
}

.reference-label {
  margin: 10px 0 32px;
  font-size: 12.5px;
  color: var(--color-text-hint);
}

.no-avatar-card {
  width: 100%;
  padding: 18px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 16px;
  font-size: 13.5px;
  line-height: 1.6;
  color: var(--color-text-secondary);
  text-align: center;
  margin-bottom: 20px;
}

.cta {
  width: 100%;
}

/* ---- Liveness overlay ---- */

.liveness {
  position: fixed;
  top: 0;
  bottom: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 480px;
  z-index: 50;
  background: var(--color-background);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 18px 22px calc(24px + env(safe-area-inset-bottom));
}

.liveness.flashing {
  animation: screen-flash 1.2s linear infinite;
}

@keyframes screen-flash {
  0% { background: #fef6e4; }
  25% { background: #e4f0fe; }
  50% { background: #fee4ee; }
  75% { background: #e6fee4; }
  100% { background: #fef6e4; }
}

.liveness-close {
  align-self: flex-start;
  font-size: 20px;
  line-height: 1;
  padding: 8px;
  margin-left: -8px;
}

.warn {
  display: flex;
  gap: 10px;
  align-items: flex-start;
  width: 100%;
  padding: 12px 14px;
  border-radius: 12px;
  background: rgba(255, 196, 0, 0.12);
  margin-top: 4px;
}

.warn-icon {
  font-size: 16px;
}

.warn-title {
  margin: 0;
  font-size: 13px;
  font-weight: 700;
}

.warn-body {
  margin: 2px 0 0;
  font-size: 12px;
  line-height: 1.5;
  color: var(--color-text-secondary);
}

.guide {
  margin: 22px 0 18px;
  min-height: 24px;
  font-size: 16.5px;
  font-weight: 700;
  color: var(--color-accent);
  text-align: center;
}

.oval {
  width: min(76vw, 320px);
  aspect-ratio: 3 / 4;
  border-radius: 50%;
  overflow: hidden;
  border: 3px solid var(--color-text-primary);
  background: #111;
  flex-shrink: 0;
}

.camera {
  width: 100%;
  height: 100%;
  object-fit: cover;
  transform: scaleX(-1);
}

.liveness-cta {
  width: 100%;
  margin-top: auto;
}
</style>
