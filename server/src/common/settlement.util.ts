/// Fallback settlement: how long after the confirmed plan time the escrow
/// auto-settles to the earner when the poster never taps "completed"
/// (lazy, on reads). Read per call so demo/test runs can override it via
/// the environment at any point.
export function autoSettleDelayMs(): number {
  return Number(process.env.AUTO_SETTLE_DELAY_MS ?? 86_400_000);
}
