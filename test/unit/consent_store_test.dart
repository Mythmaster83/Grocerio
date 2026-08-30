import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/core/config/legal_config.dart';
import 'package:grocer/features/legal/data/consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ConsentStore is device-local state in SharedPreferences, which has an
  // in-memory mock for tests — no plugins or disk needed.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConsentStore', () {
    test('a fresh install has not accepted the policy', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ConsentStore.hasAcceptedCurrentPolicy(), isFalse);
    });

    test('accepting the current policy is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      await ConsentStore.acceptCurrentPolicy();
      expect(await ConsentStore.hasAcceptedCurrentPolicy(), isTrue);
    });

    test('an accepted version older than the current one re-prompts', () async {
      // Simulate a device that accepted a previous policy version.
      SharedPreferences.setMockInitialValues({
        'grocerio.privacy_policy_accepted_version':
            LegalConfig.privacyPolicyVersion - 1,
      });
      expect(await ConsentStore.hasAcceptedCurrentPolicy(), isFalse);
    });

    test('an accepted version newer than current still counts as accepted',
        () async {
      SharedPreferences.setMockInitialValues({
        'grocerio.privacy_policy_accepted_version':
            LegalConfig.privacyPolicyVersion + 1,
      });
      expect(await ConsentStore.hasAcceptedCurrentPolicy(), isTrue);
    });
  });
}
