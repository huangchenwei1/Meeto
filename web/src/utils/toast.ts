import { ref } from 'vue';

export interface Toast {
  id: number;
  text: string;
}

export const toasts = ref<Toast[]>([]);

let nextId = 1;

/** Transient snackbar-style message at the bottom of the frame. */
export function showToast(text: string): void {
  const id = nextId++;
  toasts.value.push({ id, text });
  setTimeout(() => {
    toasts.value = toasts.value.filter((t) => t.id !== id);
  }, 2600);
}
