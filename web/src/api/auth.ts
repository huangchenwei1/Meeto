import { api, ApiError } from '@/api/client';
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
    gender: res.user.gender ?? 'FEMALE',
    role: res.user.role ?? 'USER',
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

export async function register(input: {
  registrationToken: string;
  name: string;
  gender: string;
  role: string;
}): Promise<void> {
  const res = (await api.post('/auth/register', input)) as AuthResponse;
  applySession(res);
}
