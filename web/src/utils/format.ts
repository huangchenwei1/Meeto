import { strings } from '@/constants/strings';

/** Formats 2000 as "2,000 tokens". */
export function formatMoney(amount: number): string {
  const sign = amount < 0 ? '-' : '';
  const value = Math.abs(amount).toLocaleString('en-US');
  return `${sign}${value} tokens`;
}

/** Relative time, e.g. "Ngayon lang" / "5 min ang nakalipas". */
export function relativeTime(date: Date): string {
  const diffMs = Date.now() - date.getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return strings.justNow;
  if (minutes < 60) return strings.minutesAgo(minutes);
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return strings.hoursAgo(hours);
  return strings.daysAgo(Math.floor(hours / 24));
}

const pad = (n: number) => String(n).padStart(2, '0');

/** Filipino month abbreviations, indexed by Date.getMonth(). */
const MONTH_LABELS = [
  'Ene', 'Peb', 'Mar', 'Abr', 'May', 'Hun',
  'Hul', 'Ago', 'Set', 'Okt', 'Nob', 'Dis',
];

/** "Mar 8, 14:30" style local date-time. */
export function formatDateTime(date: Date): string {
  return `${MONTH_LABELS[date.getMonth()]} ${date.getDate()}, ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** "14:30" local time. */
export function formatTime(date: Date): string {
  return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** "2026-11-09T14:30" for datetime-local inputs. */
export function toDatetimeLocalValue(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
