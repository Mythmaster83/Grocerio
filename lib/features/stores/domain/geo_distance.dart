import 'dart:math' as math;

/// Distance helpers for sorting store locations nearest-first.
class GeoDistance {
  GeoDistance._();

  /// Great-circle distance in miles (Earth radius ≈ 3958.8 mi).
  static double milesBetween({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthMi = 3958.8;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthMi * c;
  }

  static double _rad(double deg) => deg * math.pi / 180.0;

  /// [approximate] uses whole miles with a `~` so coarse GPS is not shown as
  /// more precise than it is. Precise GPS keeps one decimal under 10 mi.
  static String formatMiles(double miles, {bool approximate = false}) {
    if (approximate) {
      if (miles < 0.5) return '~< 0.5 mi';
      return '~${miles.round()} mi';
    }
    if (miles < 0.1) return '< 0.1 mi';
    if (miles < 10) return '${miles.toStringAsFixed(1)} mi';
    return '${miles.round()} mi';
  }
}
