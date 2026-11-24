<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { requestOtp, verifyOtp } from '@/api/auth';
import { strings } from '@/constants/strings';

const DEMO_PHONE = '+639170000000';
const DEMO_CODE_FALLBACK = '000000';
const SPLASH_VIDEO_URL = '/splash-bg.mp4';

const router = useRouter();

const googleBusy = ref(false);
const googleError = ref<string | null>(null);

const sheetOpen = ref(false);
const step = ref<'phone' | 'code'>('phone');
const phoneDigits = ref('');
const code = ref('');
const devCode = ref<string | null>(null);
const sheetError = ref<string | null>(null);
const sheetBusy = ref(false);
const phoneInput = ref<HTMLInputElement | null>(null);
const codeInput = ref<HTMLInputElement | null>(null);

const fullPhone = () => `+63${phoneDigits.value.trim()}`;

async function continueWithGoogle(): Promise<void> {
  googleBusy.value = true;
  googleError.value = null;
  try {
    const echoed = await requestOtp(DEMO_PHONE);
    const result = await verifyOtp(DEMO_PHONE, echoed ?? DEMO_CODE_FALLBACK);
    if (result.kind === 'loggedIn') {
      await router.replace('/hall');
    } else {
      await router.replace({
        name: 'setup',
        query: { registrationToken: result.registrationToken },
      });
    }
  } catch {
    googleError.value = strings.errorGeneric;
  } finally {
    googleBusy.value = false;
  }
}

async function openTestLogin(): Promise<void> {
  step.value = 'phone';
  code.value = '';
  devCode.value = null;
  sheetError.value = null;
  sheetOpen.value = true;
  await nextTick();
  phoneInput.value?.focus();
}

function closeSheet(): void {
  if (sheetBusy.value) return;
  sheetOpen.value = false;
}

function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') closeSheet();
}

onMounted(() => window.addEventListener('keydown', onKeydown));
onUnmounted(() => window.removeEventListener('keydown', onKeydown));

async function runSheet(action: () => Promise<void>): Promise<void> {
  sheetBusy.value = true;
  sheetError.value = null;
  try {
    await action();
  } catch (error) {
    sheetError.value =
      error instanceof Error && error.message === 'INVALID_CODE'
        ? strings.loginInvalidCode
        : strings.errorGeneric;
  } finally {
    sheetBusy.value = false;
  }
}

async function submitPhone(): Promise<void> {
  if (phoneDigits.value.trim().length < 9) {
    sheetError.value = strings.loginPhoneRequiredHint;
    return;
  }
  await runSheet(async () => {
    devCode.value = await requestOtp(fullPhone());
    step.value = 'code';
    await nextTick();
    codeInput.value?.focus();
  });
}

async function submitCode(): Promise<void> {
  await runSheet(async () => {
    const result = await verifyOtp(fullPhone(), code.value.trim());
    if (result.kind === 'loggedIn') {
      await router.replace('/hall');
    } else {
      await router.replace({
        name: 'setup',
        query: { registrationToken: result.registrationToken },
      });
    }
  });
}

function changeNumber(): void {
  step.value = 'phone';
  code.value = '';
  devCode.value = null;
  sheetError.value = null;
  void nextTick(() => phoneInput.value?.focus());
}
</script>

<template>
  <div class="login-page">
    <video
      class="bg"
      autoplay
      muted
      loop
      playsinline
      :src="SPLASH_VIDEO_URL"
    ></video>
    <div class="veil"></div>
    <div class="grain"></div>

    <header class="top">
      <button type="button" class="test-login" @click="openTestLogin">
        {{ strings.loginTestCta }}
      </button>
    </header>

    <main class="stage">
      <span class="mark" aria-hidden="true"></span>
      <p class="brand">{{ strings.splashBrand }}</p>
      <h1 class="hero">{{ strings.loginHero }}</h1>
      <p class="aside">{{ strings.loginAside }}</p>
      <p class="tagline">{{ strings.loginTagline }}</p>
    </main>

    <footer class="dock">
      <button
        type="button"
        class="google-btn"
        :disabled="googleBusy"
        @click="continueWithGoogle"
      >
        <svg class="google-mark" viewBox="0 0 48 48" aria-hidden="true">
          <path
            fill="#FFC107"
            d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.3 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 8 3.1l5.7-5.7C34.2 6.1 29.4 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.2-.1-2.3-.4-3.5z"
          />
          <path
            fill="#FF3D00"
            d="M6.3 14.7l6.6 4.8C14.7 16 19 12 24 12c3.1 0 5.8 1.2 8 3.1l5.7-5.7C34.2 6.1 29.4 4 24 4 16.3 4 9.6 8.3 6.3 14.7z"
          />
          <path
            fill="#4CAF50"
            d="M24 44c5.2 0 10-2 13.6-5.2l-6.3-5.3C29.3 35.1 26.8 36 24 36c-5.3 0-9.7-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z"
          />
          <path
            fill="#1976D2"
            d="M43.6 20.5H42V20H24v8h11.3c-1.1 3.2-3.5 5.7-6.6 7.1l6.3 5.3C37.4 38.3 44 33 44 24c0-1.2-.1-2.3-.4-3.5z"
          />
        </svg>
        <span>{{ googleBusy ? '...' : strings.loginGoogleCta }}</span>
      </button>
      <p v-if="googleError" class="error">{{ googleError }}</p>
    </footer>

    <div
      v-if="sheetOpen"
      class="sheet-root"
      @click.self="closeSheet"
    >
      <div
        class="sheet"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="step === 'phone' ? 'login-phone-title' : 'login-code-title'"
      >
        <div class="sheet-handle" aria-hidden="true"></div>
        <div class="sheet-head">
          <h2
            :id="step === 'phone' ? 'login-phone-title' : 'login-code-title'"
            class="sheet-title"
          >
            {{ step === 'phone' ? strings.loginPhoneTitle : strings.loginCodeTitle }}
          </h2>
          <button
            type="button"
            class="sheet-close"
            :aria-label="strings.loginCloseLabel"
            :disabled="sheetBusy"
            @click="closeSheet"
          >
            ×
          </button>
        </div>

        <template v-if="step === 'phone'">
          <div class="phone-row">
            <span class="prefix">+63</span>
            <input
              ref="phoneInput"
              v-model="phoneDigits"
              class="text-field"
              type="tel"
              inputmode="numeric"
              autocomplete="tel"
              maxlength="10"
              placeholder="9XX XXX XXXX"
              @keyup.enter="submitPhone"
            />
          </div>
        </template>

        <template v-else>
          <p class="lead">{{ strings.loginCodeSentTo(fullPhone()) }}</p>
          <input
            ref="codeInput"
            v-model="code"
            class="text-field"
            type="text"
            inputmode="numeric"
            maxlength="6"
            autocomplete="one-time-code"
            :placeholder="strings.loginCodeHint"
            @keyup.enter="submitCode"
          />
          <div v-if="devCode" class="dev-code">
            {{ strings.loginDevCodeNote(devCode) }}
          </div>
        </template>

        <p v-if="sheetError" class="sheet-error">{{ sheetError }}</p>

        <button
          type="button"
          class="btn-primary submit"
          :disabled="sheetBusy"
          @click="step === 'phone' ? submitPhone() : submitCode()"
        >
          {{
            sheetBusy
              ? '...'
              : step === 'phone'
                ? strings.loginContinueCta
                : strings.loginVerifyCta
          }}
        </button>

        <button
          v-if="step === 'code'"
          type="button"
          class="change-number"
          :disabled="sheetBusy"
          @click="changeNumber"
        >
          {{ strings.loginChangeNumber }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  position: relative;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: #120e0c;
  color: #fff;
}

.bg {
  position: absolute;
  inset: -8%;
  width: 116%;
  height: 116%;
  object-fit: cover;
  object-position: center 42%;
  pointer-events: none;
}

.veil {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(
      180deg,
      rgb(8 6 5 / 42%) 0%,
      rgb(8 6 5 / 8%) 30%,
      rgb(8 6 5 / 22%) 52%,
      rgb(8 6 5 / 78%) 100%
    );
  pointer-events: none;
}

.grain {
  position: absolute;
  inset: 0;
  pointer-events: none;
  opacity: 0.16;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 160 160' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  mix-blend-mode: overlay;
}

.top,
.stage,
.dock {
  position: relative;
  z-index: 1;
}

.top {
  display: flex;
  justify-content: flex-end;
  padding: calc(12px + env(safe-area-inset-top)) 18px 0;
}

.test-login {
  padding: 8px 2px;
  color: #fff;
  font-size: 14px;
  letter-spacing: 0.06em;
  text-decoration: underline;
  text-underline-offset: 5px;
  text-decoration-color: rgb(255 255 255 / 70%);
}

.stage {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 32px 28px 36px;
}

.mark {
  width: 28px;
  height: 2px;
  margin-bottom: 18px;
  background: var(--color-accent);
}

.brand {
  margin: 0 0 16px;
  font-family: 'Didot', 'Bodoni MT', 'Songti SC', 'STSong', serif;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 0.46em;
  text-indent: 0.46em;
}

.hero {
  margin: 0;
  max-width: 11em;
  font-family: 'Iowan Old Style', Palatino, 'Palatino Linotype', Georgia, serif;
  font-size: 34px;
  font-weight: 500;
  line-height: 1.2;
  letter-spacing: -0.01em;
  text-wrap: balance;
}

.aside {
  margin: 16px 0 0;
  max-width: 22em;
  color: #fff;
  font-size: 14px;
  line-height: 1.55;
}

.tagline {
  margin: 22px 0 0;
  color: #fff;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.22em;
}

.dock {
  padding: 0 20px calc(28px + env(safe-area-inset-bottom));
}

.google-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
  width: 100%;
  height: 52px;
  border-radius: 999px;
  background: #fff;
  color: #1c1917;
  font-size: 15px;
  font-weight: 600;
}

.google-mark {
  width: 20px;
  height: 20px;
  flex: none;
}

.error {
  margin: 12px 4px 0;
  color: #ffb4a8;
  font-size: 13px;
}

.brand,
.hero,
.aside,
.tagline,
.dock {
  animation: rise-in 0.8s ease both;
}

.hero {
  animation-delay: 0.1s;
}

.aside {
  animation-delay: 0.18s;
}

.tagline {
  animation-delay: 0.26s;
}

.dock {
  animation-delay: 0.34s;
}

.sheet-root {
  position: absolute;
  inset: 0;
  z-index: 5;
  display: flex;
  align-items: flex-end;
  background: rgb(8 6 5 / 46%);
}

.sheet {
  width: 100%;
  padding: 10px 20px calc(24px + env(safe-area-inset-bottom));
  border-radius: 24px 24px 0 0;
  background: #fff;
  color: var(--color-text-primary);
  animation: sheet-in 0.32s ease;
}

.sheet-handle {
  width: 36px;
  height: 4px;
  margin: 0 auto 14px;
  border-radius: 999px;
  background: var(--color-divider);
}

.sheet-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
}

.sheet-title {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  line-height: 1.3;
}

.sheet-close {
  width: 32px;
  height: 32px;
  margin-top: -4px;
  border-radius: 999px;
  background: var(--color-button-soft);
  color: var(--color-text-secondary);
  font-size: 22px;
  line-height: 1;
}

.lead {
  margin: 0 0 12px;
  color: var(--color-text-secondary);
  font-size: 14px;
}

.phone-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.prefix {
  flex: none;
  font-size: 15px;
  font-weight: 600;
  color: var(--color-text-secondary);
}

.dev-code {
  margin-top: 10px;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--color-accent-soft);
  color: var(--color-accent);
  font-size: 13px;
}

.sheet-error {
  margin: 12px 0 0;
  color: var(--color-danger);
  font-size: 13px;
}

.submit {
  margin-top: 20px;
}

.change-number {
  display: block;
  margin: 12px auto 0;
  padding: 8px;
  color: var(--color-text-secondary);
  font-size: 14px;
}

@keyframes rise-in {
  from {
    opacity: 0;
    transform: translateY(16px);
  }
  to {
    opacity: 1;
    transform: none;
  }
}

@keyframes sheet-in {
  from {
    transform: translateY(24px);
  }
  to {
    transform: none;
  }
}

@media (prefers-reduced-motion: reduce) {
  .brand,
  .hero,
  .aside,
  .tagline,
  .dock,
  .sheet {
    animation: none;
  }
}
</style>
