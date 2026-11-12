import { ForbiddenException } from '@nestjs/common';
import type { User } from '@prisma/client';
import { VerificationStatus } from './enums.js';

/**
 * Real-person verification is parked.
 * Keep this in sync with `realPersonVerificationEnabled` in
 * web/src/constants/features.ts.
 * While false, contact-creating actions do not require verification.
 */
export const realPersonVerificationEnabled = false;

/// Machine-readable error code the client matches on to open the
/// verification flow.
export const VERIFICATION_REQUIRED = 'VERIFICATION_REQUIRED';

/// Guards actions that create real-world contact (posting, applying,
/// paying, withdrawing). Browsing stays open to unverified users.
export function assertVerified(user: User): void {
  if (!realPersonVerificationEnabled) return;
  if (user.verificationStatus !== VerificationStatus.verified) {
    throw new ForbiddenException(VERIFICATION_REQUIRED);
  }
}
