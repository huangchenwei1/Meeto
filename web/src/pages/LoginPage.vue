<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';

import { requestOtp, verifyOtp } from '@/api/auth';
import { strings } from '@/constants/strings';

const router = useRouter();

const step = ref<'phone' | 'code'>('phone');
const phoneDigits = ref('');
const code = ref('');
const devCode = ref<string | null>(null);
const error = ref<string | null>(null);
const busy = ref(false);

const fullPhone = () => `+63${phoneDigits.value.trim()}`;

async function run(action: () => Promise<void>): Promise<void> {
  busy.value = true;
  error.value = null;
  try {
    await action();
  } catch (e) {
    error.value =
      e instanceof Error && e.message === 'INVALID_CODE'
        ? strings.loginInvalidCode
        : strings.errorGeneric;
  } finally {
    busy.value = false;
  }
}

async function submitPhone(): Promise<void> {
  if (phoneDigits.value.trim().length < 9) {
    error.value = strings.loginPhoneRequiredHint;
    return;
  }
  await run(async () => {
    devCode.value = await requestOtp(fullPhone());
    step.value = 'code';
  });
}

async function submitCode(): Promise<void> {
  await run(async () => {
    const result = await verifyOtp(fullPhone(), code.value.trim());
    if (result.kind === 'loggedIn') {
      await router.replace('/hall');
    } else {
      // New phone: the onboarding wizard collects role + gender + name and
      // registers the account itself, then fills in the profile.
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
  error.value = null;
}
</script>

<template>
  <div class="login-page">
    <h1 class="logo">Meeto</h1>
    <p class="tagline">{{ strings.loginTagline }}</p>

    <template v-if="step === 'phone'">
      <p class="lead">{{ strings.loginSignInTitle }}</p>
      <div class="phone-row">
        <span class="prefix">+63</span>
        <input
          v-model="phoneDigits"
          class="text-field"
          type="tel"
          inputmode="numeric"
          placeholder="9XX XXX XXXX"
          @keyup.enter="submitPhone"
        />
      </div>
    </template>

    <template v-else>
      <p class="lead">{{ strings.loginCodeSentTo(fullPhone()) }}</p>
      <input
        v-model="code"
        class="text-field"
        type="text"
        inputmode="numeric"
        maxlength="6"
        :placeholder="strings.loginCodeHint"
        @keyup.enter="submitCode"
      />
      <div v-if="devCode" class="dev-code">
        {{ strings.loginDevCodeNote(devCode) }}
      </div>
    </template>

    <p v-if="error" class="error">{{ error }}</p>

    <button
      class="btn-primary submit"
      :disabled="busy"
      @click="step === 'phone' ? submitPhone() : submitCode()"
    >
      {{
        busy
          ? '...'
          : step === 'phone'
            ? strings.loginContinueCta
            : strings.loginVerifyCta
      }}
    </button>

    <button v-if="step === 'code'" class="change-number" :disabled="busy" @click="changeNumber">
      {{ strings.loginChangeNumber }}
    </button>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100dvh;
  padding: 64px 24px 24px;
  background: var(--color-background);
  display: flex;
  flex-direction: column;
}

.logo {
  font-size: 40px;
  font-weight: 800;
  margin: 0;
}

.tagline {
  margin: 8px 0 48px;
  font-size: 13px;
  font-weight: 600;
  letter-spacing: 2px;
  color: var(--color-accent);
}

.lead {
  font-size: 16px;
  color: var(--color-text-secondary);
  margin: 0 0 16px;
}

.phone-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.prefix {
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

.error {
  color: var(--color-danger);
  font-size: 13px;
  margin: 12px 0 0;
}

.submit {
  margin-top: 24px;
}

.change-number {
  margin-top: 12px;
  align-self: center;
  color: var(--color-text-secondary);
  font-size: 14px;
  padding: 8px;
}
</style>
