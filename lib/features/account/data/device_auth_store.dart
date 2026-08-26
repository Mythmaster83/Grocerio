import 'package:shared_preferences/shared_preferences.dart';

/// Remembers on this install whether someone is signed in (and which email).
///
/// Supabase already persists the JWT session across restarts. This mirror is
/// for fast UI / offline checks ("was this device signed in?") without waiting
/// on a network round-trip, and is cleared on sign-out / account deletion.
class DeviceAuthStore {
  DeviceAuthStore._();

  static const _loggedInKey = 'grocerio.device_logged_in';
  static const _emailKey = 'grocerio.device_signed_in_email';

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loggedInKey) ?? false;
  }

  static Future<String?> signedInEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<void> markSignedIn(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, true);
    await prefs.setString(_emailKey, email.trim());
  }

  static Future<void> markSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    await prefs.remove(_emailKey);
  }
}
