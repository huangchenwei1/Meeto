import { api, ApiError, majorToMinor, minorToMajor, resolveMediaUrl } from '@/api/client';
import { strings } from '@/constants/strings';
import type {
  CurrentUser,
  PlaceSuggestion,
  ProfileInfoItem,
  ProfileStat,
  UserDetail,
  WalletSummary,
  WithdrawalRecord,
} from '@/types/models';

type Json = Record<string, unknown>;

/** Honest stats: both counts come from real posts and orders. */
function stats(json: Json): ProfileStat[] {
  return [
    {
      value: String((json.activityPosts as number) ?? 0),
      label: strings.profileActivityPosts,
    },
    {
      value: String((json.activitiesCompleted as number) ?? 0),
      label: strings.profileDatesCompleted,
    },
  ];
}

export async function fetchCurrentUser(): Promise<CurrentUser> {
  const json = (await api.get('/users/me')) as Json;
  const city = (json.city as string) ?? '';
  const shortId = (json.id as string).substring(0, 6).toUpperCase();
  return {
    id: json.id as string,
    name: json.name as string,
    gender: json.gender as string,
    avatarUrl: resolveMediaUrl((json.avatarUrl as string) ?? ''),
    meta: (json.meta as string) ?? '',
    isVerified: (json.isVerified as boolean) ?? false,
    idLine:
      city.length === 0 ? `Meeto ID ${shortId}` : `Meeto ID ${shortId} · ${city}`,
    stats: stats(json),
  };
}

const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

export async function fetchUserDetail(
  userId: string,
): Promise<UserDetail | null> {
  let json: Json;
  try {
    json = (await api.get(`/users/${userId}`)) as Json;
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 404) return null;
    throw error;
  }
  const city = (json.city as string) ?? '';
  const country = (json.country as string) ?? '';
  const job = (json.job as string) ?? '';
  const education = (json.education as string) ?? '';
  const heightCm = json.heightCm as number | null;
  const weightKg = json.weightKg as number | null;
  const livesIn = [city, country].filter((p) => p.length > 0).join(' · ');
  const joined = new Date(json.joinedAt as string);
  const info: ProfileInfoItem[] = [];
  if (job.length > 0) info.push({ label: strings.profileJobLabel, value: job });
  if (education.length > 0) {
    info.push({ label: strings.profileEducationLabel, value: education });
  }
  if (heightCm != null) {
    info.push({ label: strings.profileHeightLabel, value: `${heightCm} cm` });
  }
  if (weightKg != null) {
    info.push({ label: strings.profileWeightLabel, value: `${weightKg} kg` });
  }
  if (livesIn.length > 0) {
    info.push({ label: strings.profileLivesInLabel, value: livesIn });
  }
  return {
    id: json.id as string,
    name: json.name as string,
    avatarUrl: resolveMediaUrl((json.avatarUrl as string) ?? ''),
    meta: (json.meta as string) ?? '',
    isVerified: (json.isVerified as boolean) ?? false,
    city,
    joinedText: strings.joinedLine(
      `${MONTHS[joined.getMonth()]} ${joined.getFullYear()}`,
    ),
    bio: (json.bio as string) ?? '',
    tags: (json.tags as string[]) ?? [],
    photos: ((json.photos as string[]) ?? []).map(resolveMediaUrl),
    info,
    stats: stats(json),
  };
}

/** Saves profile fields; returns the fresh user payload. */
export async function updateProfile(patch: Json): Promise<Json> {
  return (await api.patch('/users/me', patch)) as Json;
}

/** Raw /users/me payload for prefilling the edit form. */
export async function fetchRawMe(): Promise<Json> {
  return (await api.get('/users/me')) as Json;
}

/** Real-person verification: submit the liveness selfie for matching. */
export async function submitVerification(selfieUrl: string): Promise<void> {
  await api.post('/verification', { selfieUrl });
}

export async function fetchWallet(): Promise<WalletSummary> {
  const json = (await api.get('/wallet')) as Json;
  return {
    monthIncome: minorToMajor(json.monthIncomeMinor as number),
    withdrawable: minorToMajor(json.withdrawableMinor as number),
  };
}

function toWithdrawal(json: Json): WithdrawalRecord {
  return {
    id: json.id as string,
    amount: minorToMajor(json.amountMinor as number),
    status: json.status as string,
    createdAt: new Date(json.createdAt as string),
  };
}

export async function fetchWithdrawals(): Promise<WithdrawalRecord[]> {
  const json = (await api.get('/wallet/withdrawals')) as Json[];
  return json.map(toWithdrawal);
}

export async function requestWithdrawal(
  amount: number,
): Promise<WithdrawalRecord> {
  return toWithdrawal(
    (await api.post('/wallet/withdrawals', {
      amountMinor: majorToMinor(amount),
    })) as Json,
  );
}

/** Search-as-you-type place suggestions from the server's POI proxy. */
export async function searchPlaces(query: string): Promise<PlaceSuggestion[]> {
  const json = (await api.get('/places/search', { q: query })) as Json[];
  return json
    .map((e) => ({
      name: (e.name as string) ?? '',
      address: (e.address as string) ?? '',
    }))
    .filter((s) => s.name.length > 0);
}
