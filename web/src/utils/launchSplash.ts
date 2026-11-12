/** Resets on a full page load, so each open of the site shows the splash once. */
let shownThisLoad = false;

export function isLaunchSplashPending(): boolean {
  return !shownThisLoad;
}

export function markLaunchSplashShown(): void {
  shownThisLoad = true;
}

/** Keeps the page after the splash inside the app. */
export function safeInternalPath(raw: unknown, signedIn: boolean): string {
  const fallback = signedIn ? '/hall' : '/login';
  if (typeof raw !== 'string') return fallback;
  if (!raw.startsWith('/') || raw.startsWith('//') || raw.includes('://')) {
    return fallback;
  }
  if (raw === '/splash' || raw.startsWith('/splash?')) return fallback;
  if (signedIn && (raw === '/login' || raw.startsWith('/login?'))) return '/hall';
  return raw;
}
