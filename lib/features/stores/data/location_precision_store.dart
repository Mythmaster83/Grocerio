import 'package:shared_preferences/shared_preferences.dart';

/// How aggressively we ask the OS for a fix on the Your stores screen.
enum LocationPrecision {
  /// Coarse / city-block level — works with approximate permission on Android 12+.
  approximate,

  /// Fine GPS — used when the user wants tighter distance sorting.
  precise,
}

/// Remembers the last precision choice on this install.
class LocationPrecisionStore {
  LocationPrecisionStore._();

  static const _key = 'grocerio.location_precision';

  static Future<LocationPrecision> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return raw == LocationPrecision.precise.name
        ? LocationPrecision.precise
        : LocationPrecision.approximate;
  }

  static Future<void> save(LocationPrecision value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}
