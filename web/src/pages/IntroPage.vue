<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';

import { beginEntry } from '@/api/auth';
import { acknowledgeIntro } from '@/constants/guest';
import { strings } from '@/constants/strings';
import { pathAfterEntry } from '@/utils/entryRoute';

const SPLASH_VIDEO_URL = '/splash-bg.mp4';
const SWIPE_THRESHOLD_PX = 48;
const VIDEO_PLAYBACK_RATE = 0.65;
/** Fade finishes, then the page stays long enough to read before it advances. */
const PAGE_HOLD_MS = 5800;
const REDUCED_HOLD_MS = 3200;
const CTA_DELAY_MS = 2400;
const REVEAL_DELAY_MS = 60;

const route = useRoute();
const router = useRouter();

const pages = strings.splashPages;
const videoRef = ref<HTMLVideoElement | null>(null);
const pageIndex = ref(0);
const busy = ref(false);
const error = ref<string | null>(null);
const reduceMotion = ref(false);
const revealed = ref(pages.map(() => false));
const ctaReady = ref(false);
const onLastPage = computed(() => pageIndex.value >= pages.length - 1);

let holdTimer = 0;
let revealTimer = 0;

function clearHold(): void {
  if (holdTimer) window.clearTimeout(holdTimer);
  holdTimer = 0;
}

function slowVideo(): void {
  const video = videoRef.value;
  if (!video) return;
  video.defaultPlaybackRate = VIDEO_PLAYBACK_RATE;
  video.playbackRate = VIDEO_PLAYBACK_RATE;
}

function playEntrance(): void {
  const index = pageIndex.value;
  ctaReady.value = false;
  clearHold();
  if (revealTimer) window.clearTimeout(revealTimer);
  // Wait past the first paint, or the opening page appears already shown.
  revealTimer = window.setTimeout(() => {
    revealTimer = 0;
    if (pageIndex.value !== index) return;
    const next = revealed.value.slice();
    next[index] = true;
    revealed.value = next;
  }, REVEAL_DELAY_MS);
  if (index >= pages.length - 1) {
    holdTimer = window.setTimeout(() => {
      if (pageIndex.value === index) ctaReady.value = true;
    }, reduceMotion.value ? 0 : CTA_DELAY_MS);
    return;
  }
  holdTimer = window.setTimeout(() => {
    if (pageIndex.value === index) goTo(index + 1);
  }, reduceMotion.value ? REDUCED_HOLD_MS : PAGE_HOLD_MS);
}

onMounted(() => {
  reduceMotion.value = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  slowVideo();
  playEntrance();
});

onUnmounted(() => {
  clearHold();
  if (revealTimer) window.clearTimeout(revealTimer);
});

watch(pageIndex, () => {
  playEntrance();
});

let pointerStartX = 0;
let pointerTracking = false;

function goTo(index: number): void {
  if (busy.value) return;
  const next = Math.min(pages.length - 1, Math.max(0, index));
  if (next === pageIndex.value) return;
  pageIndex.value = next;
  error.value = null;
}

function onPointerDown(event: PointerEvent): void {
  if (event.target instanceof Element && event.target.closest('button')) return;
  pointerStartX = event.clientX;
  pointerTracking = true;
}

function stopPointer(): void {
  pointerTracking = false;
}

function onPointerUp(event: PointerEvent): void {
  if (!pointerTracking) return;
  pointerTracking = false;
  const delta = event.clientX - pointerStartX;
  if (delta <= -SWIPE_THRESHOLD_PX) goTo(pageIndex.value + 1);
  else if (delta >= SWIPE_THRESHOLD_PX) goTo(pageIndex.value - 1);
}

async function enter(): Promise<void> {
  if (!onLastPage.value || busy.value) return;
  busy.value = true;
  error.value = null;
  try {
    const entry = await beginEntry();
    acknowledgeIntro();
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
  <section class="intro" @pointerdown="onPointerDown" @pointerup="onPointerUp" @pointercancel="stopPointer">
    <video
      ref="videoRef"
      class="bg"
      autoplay
      muted
      loop
      playsinline
      :src="SPLASH_VIDEO_URL"
      @loadedmetadata="slowVideo"
      @play="slowVideo"
    ></video>
    <div class="veil"></div>
    <div class="grain"></div>

    <div class="stage">
      <div class="track" :style="{ transform: `translateX(-${pageIndex * 100}%)` }">
        <article
          v-for="(page, index) in pages"
          :key="page.title"
          class="page"
          :class="{
            fade: !reduceMotion,
            shown: reduceMotion || revealed[index],
          }"
        >
          <p class="brand">{{ strings.splashBrand }}</p>
          <h1 class="title">{{ page.title }}</h1>
          <p class="body">{{ page.body }}</p>
          <span class="sr-only">{{ index + 1 }} / {{ pages.length }}</span>
        </article>
      </div>
    </div>

    <div class="footer">
      <div class="dots" aria-hidden="true">
        <span v-for="(page, index) in pages" :key="page.title" class="dot" :class="{ on: index === pageIndex }"></span>
      </div>
      <button
        class="enter"
        :class="{ on: onLastPage && (ctaReady || reduceMotion) }"
        :disabled="!onLastPage || busy || (!ctaReady && !reduceMotion)"
        :aria-hidden="!onLastPage"
        @click="enter"
      >
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
  padding: 14vh 0 calc(28px + env(safe-area-inset-bottom));
  background: #120e0c;
  color: #f4efe6;
  touch-action: pan-y;
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

.stage,
.footer {
  position: relative;
  z-index: 1;
}

.stage {
  flex: 1;
  overflow: hidden;
}

.track {
  display: flex;
  height: 100%;
  transition: transform 0.7s ease;
}

.page {
  flex: 0 0 100%;
  min-width: 0;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
  padding: 0 28px 8px;
}

.footer {
  flex-shrink: 0;
  margin-top: 28px;
  padding: 0 28px;
}

.brand {
  margin: 0 0 22px;
  font-family: 'Didot', 'Bodoni MT', 'Songti SC', 'STSong', serif;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: 0.48em;
  text-indent: 0.48em;
}

.page.fade .brand,
.page.fade .title,
.page.fade .body {
  opacity: 0;
  transform: translateY(22px);
}

.page.fade.shown .brand,
.page.fade.shown .title,
.page.fade.shown .body {
  opacity: 1;
  transform: none;
  transition:
    opacity 1.45s ease,
    transform 1.45s ease;
}

.page.fade.shown .title {
  transition-delay: 0.5s;
}

.page.fade.shown .body {
  transition-delay: 1.15s;
}

.title,
.body {
  margin: 0;
  font-family: 'Songti SC', 'STSong', 'Iowan Old Style', Palatino, Georgia, serif;
}

.title {
  max-width: 100%;
  font-size: 26px;
  font-weight: 500;
  line-height: 1.45;
  letter-spacing: 0.02em;
  text-wrap: balance;
}

.body {
  max-width: 18em;
  margin-top: 18px;
  font-size: 16px;
  font-weight: 400;
  line-height: 1.7;
  letter-spacing: 0.03em;
  white-space: pre-line;
  color: rgb(244 239 230 / 82%);
}

.dots {
  display: flex;
  gap: 8px;
  margin-bottom: 18px;
}

.dot {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  background: rgb(244 239 230 / 35%);
}

.dot.on {
  width: 18px;
  background: #f4efe6;
}

.enter {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  height: 48px;
  border-radius: 999px;
  border: 1px solid rgb(244 239 230 / 46%);
  background: rgb(255 248 240 / 14%);
  color: #f4efe6;
  font-family: 'Songti SC', 'STSong', 'Iowan Old Style', Palatino, Georgia, serif;
  font-size: 16px;
  letter-spacing: 0.08em;
  opacity: 0;
  pointer-events: none;
  transform: translateY(12px);
}

.enter.on {
  opacity: 1;
  pointer-events: auto;
  transform: none;
  transition:
    opacity 1.2s ease,
    transform 1.2s ease;
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

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
</style>
