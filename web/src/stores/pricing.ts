import { defineStore } from 'pinia';

import { api, minorToMajor } from '@/api/client';
import type { PricingConfig } from '@/types/models';

/** Fallback used until the server config has loaded (whole pesos). */
const DEFAULTS: PricingConfig = {
  platformFeeRate: 0.1,
  sceneBudgetTiers: {
    Coffee: [500, 800, 1200],
    Tea: [500, 800, 1200],
    Movie: [800, 1200, 1800],
    Bar: [1200, 1800, 2500],
    Dinner: [1000, 1500, 2500],
  },
  defaultFee: 1000,
};

export const usePricingStore = defineStore('pricing', {
  state: () => ({ config: DEFAULTS }),
  getters: {
    scenes: (state) => Object.keys(state.config.sceneBudgetTiers),
    platformFeeLabel: (state) =>
      `${Math.round(state.config.platformFeeRate * 100)}%`,
  },
  actions: {
    async load() {
      try {
        // Server units are basis points / minor units; the UI renders
        // rate fractions / whole pesos, so map at this boundary.
        const json = (await api.get('/config/pricing')) as {
          platformFeeRateBp: number;
          defaultFeeMinor: number;
          sceneBudgetTiers: Record<string, number[]>;
        };
        this.config = {
          platformFeeRate: json.platformFeeRateBp / 10000,
          defaultFee: minorToMajor(json.defaultFeeMinor),
          sceneBudgetTiers: Object.fromEntries(
            Object.entries(json.sceneBudgetTiers).map(([scene, tiers]) => [
              scene,
              tiers.map(minorToMajor),
            ]),
          ),
        };
      } catch {
        // Server unreachable at launch: bundled defaults keep the app
        // rendering instead of dying on a blank screen.
      }
    },
    tiersForScene(scene: string): number[] {
      return this.config.sceneBudgetTiers[scene] ?? [this.config.defaultFee];
    },
    defaultBudgetForScene(scene: string): number {
      const tiers = this.tiersForScene(scene);
      return tiers[Math.floor((tiers.length - 1) / 2)];
    },
    /** What the host receives after the platform commission. */
    netEarnings(fee: number): number {
      return Math.round(fee * (1 - this.config.platformFeeRate));
    },
  },
});
