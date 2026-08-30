import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/core/config/legal_config.dart';
import 'package:grocer/features/legal/presentation/providers/consent_controller.dart';
import 'package:grocer/features/legal/presentation/screens/privacy_consent_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors the gate GrocerApp puts around its home widget, without pulling in
/// Isar/sync/store providers the real app wires up.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(consentControllerProvider).when(
          data: (accepted) =>
              accepted ? const Text('HOME') : const PrivacyConsentScreen(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const PrivacyConsentScreen(),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows the consent gate with the key disclaimers',
      (tester) async {
    // Tall surface so the lazily-built list renders every disclaimer card and
    // the policy link, not just what fits the default 600px viewport.
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _Gate())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Grocerio'), findsOneWidget);
    expect(find.text('Data is crowdsourced'), findsOneWidget);
    expect(find.text('Prices are informational only'), findsOneWidget);
    expect(find.text('Independent and unaffiliated'), findsOneWidget);
    expect(find.text("Follow each store's rules"), findsOneWidget);
    expect(find.text('Read the full Privacy Policy & Terms'), findsOneWidget);
    // Gate is closed: home is not reachable yet.
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('continue is gated on ticking the checkbox, then reveals home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _Gate())),
    );
    await tester.pumpAndSettle();

    // Continue is disabled until the box is ticked.
    final continueButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    expect(continueButton.onPressed, isNull);

    // Tapping Continue while disabled does nothing — still on the gate.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsNothing);

    // Tick the acknowledgement, then continue.
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Welcome to Grocerio'), findsNothing);
  });

  testWidgets('a returning user who already accepted skips the gate',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'grocerio.privacy_policy_accepted_version':
          LegalConfig.privacyPolicyVersion,
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: _Gate())),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('Welcome to Grocerio'), findsNothing);
  });
}
