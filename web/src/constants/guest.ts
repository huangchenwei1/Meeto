/** Fixed identity for the stripped demo. Login, role and gender are not asked. */
export const DEFAULT_ROLE = 'USER';
export const DEFAULT_GENDER = 'MALE';
export const DEV_OTP_CODE = '123456';
export const DEMO_PHONE_STORAGE_KEY = 'meeto.demoPhone';
export const INTRO_SEEN_KEY = 'meeto.introSeen';
/** Set once the profile wizard finishes. Returning visits skip the story splash. */
export const PROFILE_READY_KEY = 'meeto.profileReady';

export function isProfileReady(): boolean {
  return localStorage.getItem(PROFILE_READY_KEY) === '1';
}

export function markProfileReady(): void {
  localStorage.setItem(PROFILE_READY_KEY, '1');
}
