import { createPinia } from 'pinia';
import { createApp } from 'vue';

import App from './App.vue';
import { router } from './router';
import { usePricingStore } from './stores/pricing';
import './styles/base.css';

const app = createApp(App);
app.use(createPinia());
app.use(router);

// Pricing (commission rate, per-scene fees) is platform-controlled and
// loaded before mount so every screen renders consistent money. Failure
// falls back to bundled defaults inside the store.
void usePricingStore()
  .load()
  .finally(() => app.mount('#app'));
