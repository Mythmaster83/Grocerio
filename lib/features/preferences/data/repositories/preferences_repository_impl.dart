import 'package:grocer/core/utils/result.dart';
import 'package:grocer/features/preferences/domain/entities/app_preferences.dart';
import 'package:grocer/features/preferences/domain/repositories/preferences_repository.dart';
import '../datasources/preferences_local_datasource.dart';
import '../models/preferences_model.dart';
import 'package:flutter/material.dart'; // ThemeMode, Color (until Phase E)
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
    // TODO: implement save
    throw UnimplementedError();
  }
  
  

}