import { ref } from 'vue';

export interface ConfirmRequest {
  title: string;
  body: string;
  yesLabel: string;
  noLabel: string;
  danger: boolean;
  resolve: (confirmed: boolean) => void;
}

export const activeConfirm = ref<ConfirmRequest | null>(null);

/** Promise-based modal confirm; rendered by ConfirmHost in App.vue. */
export function confirmDialog(options: {
  title: string;
  body: string;
  yesLabel: string;
  noLabel: string;
  danger?: boolean;
}): Promise<boolean> {
  return new Promise((resolve) => {
    activeConfirm.value = {
      ...options,
      danger: options.danger ?? false,
      resolve: (confirmed) => {
        activeConfirm.value = null;
        resolve(confirmed);
      },
    };
  });
}
