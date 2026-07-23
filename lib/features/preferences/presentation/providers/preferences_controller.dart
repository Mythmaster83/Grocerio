import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../../core/di/isar_provider.dart';
import '../../data/models/preferences_model.dart';
import '../../domain/entities/app_preferences.dart';

/// Preferences are read constantly (every screen rebuild depends on theme/
/// text scale) and written rarely (settings screen only) — a plain
/// AsyncNotifier<AppPreferences> holding the current value in memory,
/// backed by Isar for persistence, fits that access pattern better than a
/// stream: we don't need live cross-isolate sync for a single-user local
/// setting, just "load once, hold in memory, write-through on change."
class PreferencesController extends AsyncNotifier<AppPreferences> {
  Isar get _isar => ref.read(isarProvider);

  @override
  Future<AppPreferences> build() async {
    final existing = await _isar.preferencesModels.get(0);
    final model = existing ?? PreferencesModel.defaults();
    if (existing == null) {
      await _isar.writeTxn(() => _isar.preferencesModels.put(model));
    }
    return _toDomain(model);
  }

  // Named `updatePrefs`, not `update`: AsyncNotifier already declares an
  // inherited `update` with an incompatible signature, so reusing that name
  // is a compile-time invalid_override error.
  Future<void> updatePrefs(AppPreferences Function(AppPreferences current) transform) async {
    final current = state.valueOrNull ?? AppPreferences.defaults();
    final updated = transform(current);
    state = AsyncData(updated); // optimistic — settings screen should feel instant
    final model = PreferencesModel()
      ..isarId = 0
      ..themeModeIndex = updated.themeMode.index
      ..accentColorValue = updated.accentColor.toARGB32()
      ..fontFamily = updated.fontFamily
      ..textScale = updated.textScale
      ..pageOrderIndices = updated.pageOrder.map((p) => p.index).toList();
    await _isar.writeTxn(() => _isar.preferencesModels.put(model));
  }

  AppPreferences _toDomain(PreferencesModel m) => AppPreferences(
        themeMode: ThemeMode.values[m.themeModeIndex],
        accentColor: Color(m.accentColorValue),
        fontFamily: m.fontFamily,
        textScale: m.textScale,
        pageOrder: m.pageOrderIndices.map((i) => HomePage.values[i]).toList(),
      );
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);
