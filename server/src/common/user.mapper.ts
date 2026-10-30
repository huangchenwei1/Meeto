import type { User } from '@prisma/client';
import { VerificationStatus } from './enums.js';

/// Public user shape exposed by the API (never leaks phone or other
/// internals). `meta` is a derived display line, e.g. "Female · 24".
export interface PublicUser {
  id: string;
  name: string;
  gender: string;
  /// USER | HOST (admins surface as their stored role; internal accounts).
  role: string;
  avatarUrl: string;
  meta: string;
  isVerified: boolean;
  bio: string;
  age: number | null;
  country: string;
  city: string;
  job: string;
  education: string;
  heightCm: number | null;
  weightKg: number | null;
  tags: string[];
  /// Scene tags a HOST offers (empty for USER accounts).
  hostScenes: string[];
  photos: string[];
  joinedAt: Date;
}

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    name: user.name,
    gender: user.gender,
    role: user.role,
    avatarUrl: user.avatarUrl,
    meta: displayMeta(user),
    isVerified: user.verificationStatus === VerificationStatus.verified,
    bio: user.bio,
    age: ageFrom(user.birthDate),
    country: user.country,
    city: user.city,
    job: user.job,
    education: user.education,
    heightCm: user.heightCm,
    weightKg: user.weightKg,
    tags: parseStringArray(user.tagsJson),
    hostScenes: parseStringArray(user.hostScenesJson),
    photos: parseStringArray(user.photosJson),
    joinedAt: user.createdAt,
  };
}

/// Age derived from the stored birth date so it never goes stale. Birth
/// dates are stored as the first day of the birth month (we only collect
/// year + month).
export function ageFrom(birthDate: Date | null): number | null {
  if (!birthDate) {
    return null;
  }
  const now = new Date();
  let age = now.getFullYear() - birthDate.getFullYear();
  const monthDiff = now.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birthDate.getDate())) {
    age -= 1;
  }
  return age;
}

/// Display line, e.g. "女 · 24" (age omitted until provided). Derived so
/// profile edits never leave a stale display line behind.
export function displayMeta(user: User): string {
  const genderLabel = user.gender === 'FEMALE' ? '\u5973' : '\u7537';
  const age = ageFrom(user.birthDate);
  return age == null ? genderLabel : `${genderLabel} \u00b7 ${age}`;
}

function parseStringArray(json: string): string[] {
  try {
    const parsed: unknown = JSON.parse(json);
    return Array.isArray(parsed)
      ? parsed.filter((p): p is string => typeof p === 'string')
      : [];
  } catch {
    return [];
  }
}
