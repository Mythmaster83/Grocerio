import 'package:grocer/core/utils/result.dart';
import 'package:grocer/features/preferences/domain/entities/app_preferences.dart';
import 'package:grocer/features/preferences/domain/repositories/preferences_repository.dart';
import '../datasources/preferences_local_datasource.dart';
import '../models/preferences_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';

class PreferencesRepositoryImpl implements PreferencesRepository{
  final PreferencesLocalDataSource _local;
  PreferencesRepositoryImpl(this._local);

  @override
  Future<Result<AppPreferences>> load() async {
    try {
      final model = await _local.load();
      return Result.ok(_toDomain(model));
    } on StorageException catch(e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure("Could not load preferences", cause: e));
    }
  }

  @override
  Future<Result<void>> save(AppPreferences prefs) async {
    try {
      await _local.save(_fromDomain(prefs));
      return const Result.ok(null);
    } on StorageException catch(e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Failed to save preferences', cause: e));
    }
  }

  AppPreferences _toDomain(PreferencesModel m) => AppPreferences(
    themeModeIndex: m.themeModeIndex,
    accentColorValue: m.accentColorValue,
    fontFamily: m.fontFamily,
    textScale: m.textScale,
    pageOrder: _pageOrderFromStoredIndices(m.pageOrderIndices),
  );

  /// Maps stored indices → [HomePage], dropping the removed Schedule tab.
  ///
  /// Legacy enum was `lists=0, schedule=1, settings=2`. Current is
  /// `lists=0, settings=1`. If a `2` is present we treat `1` as the old
  /// schedule slot and ignore it; otherwise `1` means settings.
  static List<HomePage> _pageOrderFromStoredIndices(List<int> indices) {
    final hasLegacySettings = indices.contains(2);
    final order = <HomePage>[];
    for (final i in indices) {
      if (i == 0) {
        order.add(HomePage.lists);
      } else if (i == 2) {
        order.add(HomePage.settings);
      } else if (i == 1 && !hasLegacySettings) {
        order.add(HomePage.settings);
      }
    }
    for (final page in HomePage.values) {
      if (!order.contains(page)) order.add(page);
    }
    return order;
  }

  PreferencesModel _fromDomain(AppPreferences p) => PreferencesModel()
    ..isarId = 0
    ..themeModeIndex = p.themeModeIndex
    ..accentColorValue = p.accentColorValue
    ..fontFamily = p.fontFamily
    ..textScale = p.textScale
    ..pageOrderIndices = p.pageOrder.map((page) => page.index).toList();
}