import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

/// Backend credentials, supplied at build time.
///
/// Compile-time `dart-define` rather than a bundled `.env` file: the anon key is
/// not a secret (row-level security is what protects the data), but shipping a
/// parsed config file means a missing file becomes a runtime crash. This way an
/// unconfigured build simply has empty strings and runs offline.
///
/// Everything network-related in the app checks [isConfigured] first, so the
/// local-only behaviour that shipped before accounts existed remains reachable
/// and testable.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');

  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Supabase renamed this key; older dashboards and existing build scripts
  /// still call it the anon key, so both names are accepted.
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get publishableKey =>
      _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Must match the intent filter in AndroidManifest.xml and the redirect URL
  /// registered in the Supabase dashboard, or magic links open a browser page
  /// and never come back to the app.
  static const authRedirectUrl = 'io.grocerio://login-callback/';

  /// HTTPS page after email confirmation (`netlify-privacy/auth-confirmed.html`).
  ///
  /// Pass via `--dart-define=AUTH_EMAIL_REDIRECT_URL=https://…/auth-confirmed.html`.
  /// Must be allowlisted under Authentication → URL Configuration → Redirect URLs.
  /// When empty, confirm emails fall back to Supabase **Site URL** — do not leave
  /// Site URL as `http://localhost:3000` or users see "connection refused".
  static const authEmailRedirectUrl =
      String.fromEnvironment('AUTH_EMAIL_REDIRECT_URL');

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static bool _initialized = false;

  /// Safe to call unconditionally; does nothing without credentials.
  static Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    try {
      await Supabase.initialize(
        url: url,
        publishableKey: publishableKey,
        authOptions: const FlutterAuthClientOptions(
          // Persist session to disk so relaunching the app keeps the user
          // signed in on this device until they sign out.
          autoRefreshToken: true,
        ),
      );
      _initialized = true;
    } catch (e, st) {
      // A backend that won't start must not stop the app from launching: lists
      // live in Isar and work without it.
      logger.error('Supabase initialization failed; running offline', e, st);
    }
  }

  /// Null whenever the backend is unavailable, which callers must handle rather
  /// than assume away.
  static SupabaseClient? get clientOrNull =>
      _initialized ? Supabase.instance.client : null;
}
