<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { beginEntry } from '@/api/auth';
import { INTRO_SEEN_KEY } from '@/constants/guest';
import { strings } from '@/constants/strings';
import { pathAfterEntry } from '@/utils/entryRoute';

const SPLASH_VIDEO_URL = '/splash-bg.mp4';
const LINE_INTERVAL_MS = 1100;

const route = useRoute();
const router = useRouter();

const shown = ref(0);
const busy = ref(false);
const error = ref<string | null>(null);
const total = 1 + strings.splashLines.length;
const ctaReady = computed(() => shown.value >= total);

let timer = 0;

onMounted(() => {
  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce) {
    shown.value = total;
    return;
  }
  timer = window.setInterval(() => {
    if (shown.value >= total) {
      window.clearInterval(timer);
      return;
    }
    shown.value += 1;
  }, LINE_INTERVAL_MS);
});

onUnmounted(() => {
  if (timer) window.clearInterval(timer);
});

function revealNext(event: MouseEvent): void {
  const target = event.target;
  if (target instanceof Element && target.closest('button')) return;
  if (shown.value < total) shown.value += 1;
}

async function enter(): Promise<void> {
  if (!ctaReady.value || busy.value) return;
  busy.value = true;
  error.value = null;
  try {
    const entry = await beginEntry();
    sessionStorage.setItem(INTRO_SEEN_KEY, '1');
    const next = typeof route.query.next === 'string' ? route.query.next : '';
    await router.replace(pathAfterEntry(entry, next));
  } catch {
    error.value = strings.splashEnterFailed;
  } finally {
    busy.value = false;
  }
}
</script>

<template>
  <section class="intro" @click="revealNext">
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

    <div class="copy">
      <p class="brand" :class="{ on: shown > 0 }">{{ strings.splashBrand }}</p>
      <p
        v-for="(line, index) in strings.splashLines"
        :key="line"
        class="line"
        :class="{ on: shown > index + 1 }"
      >
        {{ line }}
      </p>
    </div>

    <div class="footer">
      <button class="enter" :class="{ on: ctaReady }" :disabled="!ctaReady || busy" @click="enter">
        {{ busy ? strings.splashEntering : strings.splashEnterCta }}
      </button>
      <p v-if="error" class="error">{{ error }}</p>
    </div>
  </section>
</template>

<style scoped>
.intro {
  position: relative;
  min-height: 100dvh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 14vh 28px calc(28px + env(safe-area-inset-bottom));
  background: #120e0c;
  color: #f4efe6;
}

.bg {
  position: absolute;
  inset: -12%;
  width: 124%;
  height: 124%;
  object-fit: cover;
  object-position: center 58%;
  filter: blur(6px);
  transform: scale(1.04);
  pointer-events: none;
}

.veil {
  position: absolute;
  inset: 0;
  background:
    linear-gradient(
      180deg,
      rgb(6 10 20 / 48%) 0%,
      rgb(6 10 20 / 16%) 34%,
      rgb(6 10 20 / 6%) 52%,
      rgb(8 6 5 / 28%) 74%,
      rgb(8 6 5 / 70%) 100%
    );
  pointer-events: none;
}

.grain {
  position: absolute;
  inset: 0;
  pointer-events: none;
  opacity: 0.18;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 160 160' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
  mix-blend-mode: overlay;
}

.copy,
.footer {
  position: relative;
  z-index: 1;
  flex-shrink: 0;
}

.footer {
  margin-top: 24px;
}

.brand {
  margin: 0 0 28px;
  font-family: 'Didot', 'Bodoni MT', 'Songti SC', 'STSong', serif;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 0.48em;
  text-indent: 0.48em;
  opacity: 0;
  transform: translateY(18px);
  transition:
    opacity 0.85s ease,
    transform 0.85s ease;
}

.line {
  margin: 0;
  max-width: 18em;
  font-family: 'Iowan Old Style', Palatino, 'Palatino Linotype', Georgia, serif;
  font-size: 21px;
  font-weight: 500;
  line-height: 1.45;
  letter-spacing: 0.01em;
  text-wrap: balance;
  opacity: 0;
  transform: translateY(22px);
  transition:
    opacity 0.85s ease,
    transform 0.85s ease;
}

.line + .line {
  margin-top: 16px;
}

.brand.on,
.line.on {
  opacity: 1;
  transform: none;
}

.enter {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 48px;
  border-radius: 999px;
  border: 1px solid rgb(244 239 230 / 46%);
  background: rgb(255 248 240 / 10%);
  color: #f4efe6;
  font-family: 'Iowan Old Style', Palatino, 'Palatino Linotype', Georgia, serif;
  font-size: 16px;
  letter-spacing: 0.04em;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.9s ease;
}

.enter.on {
  opacity: 1;
  pointer-events: auto;
}

.enter:disabled {
  opacity: 0;
}

.enter.on:disabled {
  opacity: 0.7;
  pointer-events: none;
}

.error {
  margin: 12px 0 0;
  font-size: 13px;
  letter-spacing: 0.04em;
  color: #f0d2c4;
}
</style>
