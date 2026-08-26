import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../domain/entities/app_preferences.dart';
import 'preferences_di.dart'; // preferencesRepositoryProvider

/// Preferences are read constantly (every screen rebuild depends on theme/
/// text scale) and written rarely (settings screen only) — a plain
/// AsyncNotifier<AppPreferences> holding the current value in memory,
/// backed by Isar for persistence, fits that access pattern better than a
/// stream: we don't need live cross-isolate sync for a single-user local
/// setting, just "load once, hold in memory, write-through on change."
class PreferencesController extends AsyncNotifier<AppPreferences> {

  @override
  Future<AppPreferences> build() async {
    final result = await ref.read(preferencesRepositoryProvider).load();
    return result.when(
      ok: (prefs) => prefs,
      err: (failure) => throw failure, // AsyncNotifier turns this into AsyncError
    );
  }

  Future<void> updatePrefs(AppPreferences Function(AppPreferences current) transform) async {
    final current = state.valueOrNull ?? AppPreferences.defaults();
    final updated = transform(current);
    state = AsyncData(updated); // optimistic UI
    final result = await ref.read(preferencesRepositoryProvider).save(updated);
    result.when(
      ok: (_) {},
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
      },
    );
  }

  /// Remembers a unit the user typed so it shows up in the picker next time.
  /// Returns the cleaned label, or null if it wasn't usable.
  ///
  /// Deduplicated case-insensitively (typing "Bunch" after "bunch" must not
  /// create a second entry) and capped so the picker stays scannable.
  static const int maxCustomUnits = 20;

  Future<String?> rememberCustomUnit(String rawLabel) async {
    final label = InputSanitizer.sanitizeFreeText(
      rawLabel,
      maxLength: InputSanitizer.maxUnitLabelLength,
    );
    if (label.isEmpty) return null;

    final current = state.valueOrNull ?? AppPreferences.defaults();
    final alreadyKnown = current.customUnits
        .any((u) => u.toLowerCase() == label.toLowerCase());
    if (alreadyKnown) return label;

    final updated = [...current.customUnits, label];
    await updatePrefs(
      (p) => p.copyWith(
        customUnits: updated.length > maxCustomUnits
            ? updated.sublist(updated.length - maxCustomUnits)
            : updated,
      ),
    );
    return label;
  }

  Future<void> forgetCustomUnit(String label) async {
    final current = state.valueOrNull ?? AppPreferences.defaults();
    await updatePrefs(
      (p) => p.copyWith(
        customUnits: current.customUnits
            .where((u) => u.toLowerCase() != label.toLowerCase())
            .toList(),
      ),
    );
  }
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);
