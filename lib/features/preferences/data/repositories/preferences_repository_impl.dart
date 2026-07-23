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
    pageOrder: m.pageOrderIndices.map((i) => HomePage.values[i]).toList(),
  );

  PreferencesModel _fromDomain(AppPreferences p) => PreferencesModel()
    ..isarId = 0
    ..themeModeIndex = p.themeModeIndex
    ..accentColorValue = p.accentColorValue
    ..fontFamily = p.fontFamily
    ..textScale = p.textScale
    ..pageOrderIndices = p.pageOrder.map((page) => page.index).toList();
}