import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

/// Single source of truth for environment/config values.
///
/// SECURITY NOTES (read before touching this file):
/// 1. `.env` is loaded as a Flutter asset bundled into the APK/IPA at build
///    time. `.gitignore` keeps it out of source control, but it does NOT
///    stop the key from being extracted from a compiled release build —
///    anyone can unzip an APK and read bundled assets. That is an accepted
///    MVP-level risk for a low-privilege, rate-limited key like the Pexels
///    API key. It is NOT an acceptable pattern for anything with write
///    access, billing implications, or user data (auth secrets, payment
///    keys). Before this app handles anything in that second category,
///    move the corresponding calls behind a thin backend proxy (see
///    architecture.md, "Known Limitation: Client-Embedded API Keys").
/// 2. This class fails fast (throws) if a required key is missing so a
///    misconfigured build fails at startup, not silently mid-feature.
/// 3. Never `print`/`log` the raw value of a secret. [describe] exists for
///    diagnostics without leaking the value.
class EnvConfig {
  EnvConfig._();

  static const String pexelsApiKey = 'PEXELS_API_KEY';
  static const String apiBaseUrl = 'API_BASE_URL';

  static const List<String> _requiredKeys = [pexelsApiKey];

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
    final missing = _requiredKeys.where((k) => !_hasValue(k)).toList();
    if (missing.isNotEmpty) {
      logger.error('Missing required env keys: $missing');
      throw StateError(
        'Missing required environment configuration: ${missing.join(', ')}. '
        'Copy key.env.example to .env and fill in real values.',
      );
    }
  }

  static bool _hasValue(String key) {
    final v = dotenv.maybeGet(key);
    return v != null && v.trim().isNotEmpty && !v.startsWith('REPLACE_ME');
  }

  static String get(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Requested env key "$key" is not set.');
    }
    return value;
  }

  /// Safe-for-logs description — shows the key exists without leaking it.
  static String describe(String key) {
    final v = dotenv.maybeGet(key);
    if (v == null || v.isEmpty) return '$key: <unset>';
    return '$key: <set, ${v.length} chars>';
  }
}
