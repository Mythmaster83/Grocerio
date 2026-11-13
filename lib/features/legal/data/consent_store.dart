import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/legal_config.dart';

/// Records, on this install, which version of the privacy policy / terms the
/// user has accepted.
///
/// Device-local like [DeviceAuthStore] rather than in the Isar preferences row:
/// consent is a one-time per-install gate, not a synced user setting, and
/// keeping it in SharedPreferences avoids an Isar schema migration for a single
/// integer.
class ConsentStore {
  ConsentStore._();

  static const _acceptedVersionKey = 'grocerio.privacy_policy_accepted_version';

  /// True once the user has accepted a policy version at least as new as the
  /// current [LegalConfig.privacyPolicyVersion]. A never-accepted install
  /// stores 0, so it always returns false on first launch.
  static Future<bool> hasAcceptedCurrentPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getInt(_acceptedVersionKey) ?? 0;
    return accepted >= LegalConfig.privacyPolicyVersion;
  }

  /// Stamps the current policy version as accepted on this device.
  static Future<void> acceptCurrentPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _acceptedVersionKey,
      LegalConfig.privacyPolicyVersion,
    );
  }
}
