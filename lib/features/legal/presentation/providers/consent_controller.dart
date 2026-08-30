import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/consent_store.dart';

/// Whether the user has accepted the current privacy policy / terms on this
/// device. Loaded once from [ConsentStore] at startup and flipped to true when
/// the consent gate is accepted, which rebuilds [GrocerApp] into the home UI.
///
/// An AsyncNotifier (matching PreferencesController) because the initial read
/// is an async SharedPreferences load, and the app should show a brief neutral
/// splash rather than guess the value while it resolves.
class ConsentController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ConsentStore.hasAcceptedCurrentPolicy();

  /// Persist acceptance of the current policy version, then reflect it in state.
  Future<void> accept() async {
    await ConsentStore.acceptCurrentPolicy();
    state = const AsyncData(true);
  }
}

final consentControllerProvider =
    AsyncNotifierProvider<ConsentController, bool>(ConsentController.new);
