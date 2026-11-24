/** Fixed identity for the stripped demo. Login, role and gender are not asked. */
export const DEFAULT_ROLE = 'USER';
export const DEFAULT_GENDER = 'MALE';
export const DEV_OTP_CODE = '123456';
export const DEMO_PHONE_STORAGE_KEY = 'meeto.demoPhone';
/** Set once the profile wizard finishes. Does not skip the story splash. */
export const PROFILE_READY_KEY = 'meeto.profileReady';

/**
 * Story splash acknowledgement for this document only.
 * A refresh or a new tab shows the splash again; in-app navigation does not.
 */
let introAcknowledged = false;

export function isIntroAcknowledged(): boolean {
  return introAcknowledged;
}

export function acknowledgeIntro(): void {
  introAcknowledged = true;
}

export function resetIntroAcknowledgement(): void {
  introAcknowledged = false;
}

export function isProfileReady(): boolean {
  return localStorage.getItem(PROFILE_READY_KEY) === '1';
}

export function markProfileReady(): void {
  localStorage.setItem(PROFILE_READY_KEY, '1');
}
