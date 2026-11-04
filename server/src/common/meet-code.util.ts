import { randomInt } from 'node:crypto';

/// The 4-digit proof-of-meeting code generated with every order. Shown
/// only to the payer; the host asks for it in person and submits it to
/// start the service.
export function generateMeetCode(): string {
  return randomInt(0, 10_000).toString().padStart(4, '0');
}
