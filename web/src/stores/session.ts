import { defineStore } from 'pinia';

const STORAGE_KEY = 'meeto.session';

export interface SessionUser {
  id: string;
  name: string;
  avatarUrl: string;
  meta: string;
  /** 'FEMALE' | 'MALE' */
  gender: string;
  /** 'USER' | 'HOST', fixed at registration. */
  role: string;
}

interface SessionState {
  accessToken: string | null;
  refreshToken: string | null;
  user: SessionUser | null;
}

function load(): SessionState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as SessionState;
  } catch {
    // Corrupt storage falls through to the signed-out state.
  }
  return { accessToken: null, refreshToken: null, user: null };
}

export const useSessionStore = defineStore('session', {
  state: (): SessionState => load(),
  getters: {
    isSignedIn: (state) => state.accessToken !== null && state.user !== null,
    userId: (state) => state.user?.id ?? '',
    isHost: (state) => state.user?.role === 'HOST',
  },
  actions: {
    persist() {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          accessToken: this.accessToken,
          refreshToken: this.refreshToken,
          user: this.user,
        }),
      );
    },
    setTokens(access: string, refresh: string) {
      this.accessToken = access;
      this.refreshToken = refresh;
      this.persist();
    },
    setUser(user: SessionUser) {
      this.user = user;
      this.persist();
    },
    clear() {
      this.accessToken = null;
      this.refreshToken = null;
      this.user = null;
      localStorage.removeItem(STORAGE_KEY);
    },
  },
});
