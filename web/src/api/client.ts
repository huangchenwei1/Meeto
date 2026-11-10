import { useSessionStore } from '@/stores/session';

/** Base URL of the Meeto API; dev uses the Vite proxy at /api. */
export const API_BASE_URL: string =
  (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? '/api';

/** Error raised for non-2xx API responses. */
export class ApiError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly body: string,
  ) {
    super(`ApiError(${statusCode}): ${body}`);
  }

  /**
   * True when the server refused the action because the caller has not
   * completed real-person verification; the UI should open the
   * verification flow.
   */
  get verificationRequired(): boolean {
    return this.statusCode === 403 && this.body.includes('VERIFICATION_REQUIRED');
  }
}

interface RequestOptions {
  query?: Record<string, string>;
  body?: unknown;
}

let refreshPromise: Promise<boolean> | null = null;

/** Exchanges the refresh token for a new pair; false when that fails. */
async function tryRefresh(): Promise<boolean> {
  const session = useSessionStore();
  if (!session.refreshToken) return false;
  refreshPromise ??= (async () => {
    try {
      const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: session.refreshToken }),
      });
      if (!response.ok) return false;
      const json = (await response.json()) as {
        accessToken: string;
        refreshToken: string;
      };
      session.setTokens(json.accessToken, json.refreshToken);
      return true;
    } catch {
      return false;
    } finally {
      refreshPromise = null;
    }
  })();
  return refreshPromise;
}

async function request(
  method: string,
  path: string,
  options: RequestOptions = {},
  retried = false,
): Promise<unknown> {
  const session = useSessionStore();
  let url = `${API_BASE_URL}${path}`;
  if (options.query && Object.keys(options.query).length > 0) {
    url += `?${new URLSearchParams(options.query).toString()}`;
  }
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (session.accessToken) {
    headers.Authorization = `Bearer ${session.accessToken}`;
  }
  const response = await fetch(url, {
    method,
    headers,
    body:
      method === 'GET' || method === 'DELETE'
        ? undefined
        : JSON.stringify(options.body ?? {}),
  });
  if (response.status === 401 && !retried && session.refreshToken) {
    if (await tryRefresh()) {
      return request(method, path, options, true);
    }
    // The refresh token is dead too: the session is over. A hard
    // redirect to login beats leaving the page stuck on dead requests.
    session.clear();
    window.location.assign('/login');
  }
  if (response.status === 403) {
    const text = await response.text();
    // A banned account is signed out on the spot, whatever it tapped.
    if (text.includes('ACCOUNT_BANNED')) {
      session.clear();
      window.location.assign('/login');
    }
    throw new ApiError(response.status, text);
  }
  if (response.status >= 400) {
    throw new ApiError(response.status, await response.text());
  }
  const text = await response.text();
  return text.length === 0 ? null : JSON.parse(text);
}

export const api = {
  get: (path: string, query?: Record<string, string>) =>
    request('GET', path, { query }),
  post: (path: string, body?: unknown) => request('POST', path, { body }),
  patch: (path: string, body?: unknown) => request('PATCH', path, { body }),
  delete: (path: string) => request('DELETE', path),
};

/** Uploads an image (multipart) and returns its root-relative URL. */
export async function uploadImage(file: File): Promise<string> {
  const session = useSessionStore();
  const form = new FormData();
  form.append('file', file);
  const headers: Record<string, string> = {};
  if (session.accessToken) {
    headers.Authorization = `Bearer ${session.accessToken}`;
  }
  const response = await fetch(`${API_BASE_URL}/uploads`, {
    method: 'POST',
    headers,
    body: form,
  });
  if (response.status >= 400) {
    throw new ApiError(response.status, await response.text());
  }
  const json = (await response.json()) as { url: string };
  return json.url;
}

/** Converts server minor units (centavos) to the whole pesos the UI renders. */
export function minorToMajor(minor: number): number {
  return Math.round(minor / 100);
}

/** Whole pesos -> server minor units (centavos). */
export function majorToMinor(major: number): number {
  return major * 100;
}

/**
 * Media URLs are stored root-relative (e.g. `/uploads/x.jpg`); resolve
 * them against the API host for rendering. Absolute URLs pass through.
 */
export function resolveMediaUrl(url: string): string {
  return url.startsWith('/') ? `${API_BASE_URL}${url}` : url;
}

export function parseDate(value: unknown): Date | null {
  return typeof value === 'string' && value.length > 0
    ? new Date(value)
    : null;
}
