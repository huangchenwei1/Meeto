import { api, ApiError } from '@/api/client';
import {
  DEFAULT_GENDER,
  DEFAULT_ROLE,
  DEMO_PHONE_STORAGE_KEY,
  DEV_OTP_CODE,
} from '@/constants/guest';
import { useSessionStore, type SessionUser } from '@/stores/session';

export type VerifyResult =
  | { kind: 'loggedIn' }
  | { kind: 'needsProfile'; registrationToken: string };

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    name: string;
    avatarUrl?: string;
    meta?: string;
    gender?: string;
    role?: string;
  };
}

function applySession(res: AuthResponse): void {
  const session = useSessionStore();
  session.setTokens(res.accessToken, res.refreshToken);
  const user: SessionUser = {
    id: res.user.id,
    name: res.user.name,
    avatarUrl: res.user.avatarUrl ?? '',
    meta: res.user.meta ?? '',
    gender: res.user.gender ?? DEFAULT_GENDER,
    role: res.user.role ?? DEFAULT_ROLE,
  };
  session.setUser(user);
}

/** Requests a login OTP; returns the dev code echoed outside production. */
export async function requestOtp(phone: string): Promise<string | null> {
  const res = (await api.post('/auth/otp/request', { phone })) as {
    devCode?: string;
  };
  return res.devCode ?? null;
}

export async function verifyOtp(
  phone: string,
  code: string,
): Promise<VerifyResult> {
  let res: Record<string, unknown>;
  try {
    res = (await api.post('/auth/otp/verify', { phone, code })) as Record<
      string,
      unknown
    >;
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 401) {
      throw new Error('INVALID_CODE');
    }
    throw error;
  }
  if (res.status === 'NEEDS_PROFILE') {
    return {
      kind: 'needsProfile',
      registrationToken: res.registrationToken as string,
    };
  }
  applySession(res as unknown as AuthResponse);
  return { kind: 'loggedIn' };
}

function guestPhone(): string {
  const existing = localStorage.getItem(DEMO_PHONE_STORAGE_KEY);
  if (existing && /^\+[1-9]\d{7,14}$/.test(existing)) return existing;
  const suffix = Math.floor(Math.random() * 10_000_000)
    .toString()
    .padStart(7, '0');
  const phone = `+63917${suffix}`;
  localStorage.setItem(DEMO_PHONE_STORAGE_KEY, phone);
  return phone;
}

export type EntryResult =
  | { kind: 'hall' }
  | { kind: 'resume' }
  | { kind: 'setup'; registrationToken: string };

function profileStillOpen(): boolean {
  const session = useSessionStore();
  return session.isSignedIn && (session.user?.avatarUrl ?? '') === '';
}

/**
 * Opens the app without a login screen. Role and gender stay USER / MALE.
 * A new phone still goes through the profile wizard; an unfinished profile
 * resumes it.
 */
export async function beginEntry(): Promise<EntryResult> {
  const session = useSessionStore();
  if (session.isSignedIn) {
    return profileStillOpen() ? { kind: 'resume' } : { kind: 'hall' };
  }
  const phone = guestPhone();
  await requestOtp(phone);
  const result = await verifyOtp(phone, DEV_OTP_CODE);
  if (result.kind === 'loggedIn') {
    return profileStillOpen() ? { kind: 'resume' } : { kind: 'hall' };
  }
  return { kind: 'setup', registrationToken: result.registrationToken };
}

export async function register(input: {
  registrationToken: string;
  name: string;
  gender: string;
  role: string;
}): Promise<void> {
  const res = (await api.post('/auth/register', input)) as AuthResponse;
  applySession(res);
}
