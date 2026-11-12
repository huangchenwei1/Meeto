import type { EntryResult } from '@/api/auth';

/** Where the splash hands off. Story and plain boot share this. */
export function pathAfterEntry(
  entry: EntryResult,
  next: string,
): string | { name: string; query: Record<string, string> } {
  if (entry.kind === 'setup') {
    return { name: 'setup', query: { registrationToken: entry.registrationToken } };
  }
  if (entry.kind === 'resume') {
    return { name: 'setup', query: { resume: '1' } };
  }
  const blocked =
    !next.startsWith('/') ||
    next.startsWith('//') ||
    next.startsWith('/intro') ||
    next.startsWith('/boot') ||
    next.startsWith('/login') ||
    next.startsWith('/setup');
  return blocked ? '/hall' : next;
}
