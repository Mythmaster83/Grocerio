import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/app_logger.dart';

/// Single source of truth for environment/config values.
///
/// SECURITY NOTES (read before touching this file):
/// 1. `.env` is loaded as a Flutter asset bundled into the APK/IPA at build
///    time. Prefer `API_BASE_URL` → image proxy so `PEXELS_API_KEY` never
///    ships in release clients (see `backend/image-proxy/` and BACKEND_NEXT.md).
/// 2. This class fails fast (throws) if required keys for the active mode
///    are missing so a misconfigured build fails at startup.
/// 3. Never `print`/`log` the raw value of a secret. [describe] exists for
///    diagnostics without leaking the value.
class EnvConfig {
  EnvConfig._();

  static const String pexelsApiKey = 'PEXELS_API_KEY';
  static const String apiBaseUrl = 'API_BASE_URL';

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');

    final proxy = maybeApiBaseUrl();
    if (proxy != null) {
      logger.info('Image search: using API_BASE_URL proxy');
      return;
    }

    // Direct Pexels path (local/dev or until proxy is deployed).
    if (!_hasValue(pexelsApiKey)) {
      logger.error('Missing required env keys: [$pexelsApiKey]');
      throw StateError(
        'Missing required environment configuration: $pexelsApiKey '
        '(or set API_BASE_URL to the image proxy). '
        'Copy key.env.example to .env and fill in real values. '
        'See backend/image-proxy/README.md.',
      );
    }

    if (kReleaseMode) {
      logger.warning(
        'Release build using client-embedded PEXELS_API_KEY. '
        'Deploy backend/image-proxy and set API_BASE_URL before store upload.',
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

  /// Optional backend proxy base URL. Null when unset or still a placeholder.
  static String? maybeApiBaseUrl() {
    final v = dotenv.maybeGet(apiBaseUrl);
    if (v == null || v.trim().isEmpty || v.startsWith('REPLACE_ME')) {
      return null;
    }
    return v.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Safe-for-logs description — shows the key exists without leaking it.
  static String describe(String key) {
    final v = dotenv.maybeGet(key);
    if (v == null || v.isEmpty) return '$key: <unset>';
    return '$key: <set, ${v.length} chars>';
  }
}
