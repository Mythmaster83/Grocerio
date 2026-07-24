import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> setPageOrder(List<HomePage> order) =>
      updatePrefs((p) => p.copyWith(pageOrder: List<HomePage>.from(order)));
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);
