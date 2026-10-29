import { ForbiddenException } from '@nestjs/common';
import type { User } from '@prisma/client';
import { VerificationStatus } from './enums.js';

/// Machine-readable error code the client matches on to open the
/// verification flow.
export const VERIFICATION_REQUIRED = 'VERIFICATION_REQUIRED';

/// Guards actions that create real-world contact (posting, applying,
/// paying, withdrawing). Browsing stays open to unverified users.
export function assertVerified(user: User): void {
  if (user.verificationStatus !== VerificationStatus.verified) {
    throw new ForbiddenException(VERIFICATION_REQUIRED);
  }
}
