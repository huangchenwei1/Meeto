/// Money-flow clocks, read per call so demo/test runs can override them
/// via the environment at any point.

/// How long a started service runs before the escrow auto-settles to the
/// earner: the plan's own duration. AUTO_SETTLE_DELAY_MS overrides it
/// wholesale (demo servers settle a minute after the code is submitted;
/// e2e uses 0).
export function serviceRunMs(planDurationMinutes: number): number {
  const override = process.env.AUTO_SETTLE_DELAY_MS;
  if (override !== undefined) {
    return Number(override);
  }
  return planDurationMinutes * 60_000;
}

/// Both sides may cancel (full refund) within this window after payment;
/// after that the only way the money moves is meeting and submitting the
/// code.
export function cancelWindowMs(): number {
  return Number(process.env.CANCEL_WINDOW_MS ?? 30 * 60_000);
}

/// If no meet code is submitted this long after the planned start (or
/// after payment when no plan was ever set), the order forfeits: the
/// escrow goes to neither side.
export function forfeitAfterMs(): number {
  return Number(process.env.FORFEIT_AFTER_MS ?? 86_400_000);
}
