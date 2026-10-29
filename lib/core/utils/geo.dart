import 'dart:math' as math;

/// Great-circle distance in kilometers (haversine), mirroring the server's
/// implementation in src/common/geo.util.ts.
double distanceKmBetween(double lat1, double lng1, double lat2, double lng2) {
  const double earthRadiusKm = 6371;
  final double dLat = _rad(lat2 - lat1);
  final double dLng = _rad(lng2 - lng1);
  final double a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double degrees) => degrees * math.pi / 180;
