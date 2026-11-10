/**
 * Host-pitch availability windows, mirroring the server's
 * PROPOSAL_TIME_SLOTS. Hours are pickable START hours (Manila local):
 * the host working window is 09:00-22:00 and every activity runs the
 * standard 2 hours, so the latest start anywhere is 20:00.
 */
export interface ProposalSlotWindow {
  startHour: number;
  /** Latest pickable start hour (inclusive). */
  endHour: number;
}

export const PROPOSAL_SLOT_WINDOWS: Record<string, ProposalSlotWindow> = {
  ANYTIME: { startHour: 9, endHour: 20 },
  NOON: { startHour: 11, endHour: 14 },
  EVENING: { startHour: 17, endHour: 20 },
};

/** Stable option order for slot chips. */
export const PROPOSAL_SLOT_OPTIONS = ['ANYTIME', 'NOON', 'EVENING'];
