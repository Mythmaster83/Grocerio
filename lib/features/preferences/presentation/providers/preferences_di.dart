import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/isar_provider.dart';
import '../../data/datasources/preferences_local_datasource.dart';
import '../../data/repositories/preferences_repository_impl.dart';
import '../../domain/repositories/preferences_repository.dart';

final preferencesLocalDataSourceProvider = Provider<PreferencesLocalDataSource>((ref) {
  return PreferencesLocalDataSource(ref.watch(isarProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepositoryImpl(ref.watch(preferencesLocalDataSourceProvider));
});
