/// Haversine distance in kilometers between two WGS84 coordinates.
export function distanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const EARTH_RADIUS_KM = 6371;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(a));
}

/// Both meet confirmations must fall within this radius to count as
/// "together". Generous on purpose: indoor GPS drifts tens to hundreds of
/// meters (cafes, malls).
export const COLOCATION_RADIUS_KM = 0.2;

/// How long after the confirmed meet the escrow auto-settles to the earner
/// (lazy settlement; a dispute freezes it). Read per call so demo/test runs
/// can override it via the environment at any point.
export function meetSettleDelayMs(): number {
  return Number(process.env.MEET_SETTLE_DELAY_MS ?? 3_600_000);
}
