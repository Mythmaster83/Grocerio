import '../../../../core/di/isar_provider.dart';

final preferencesLocalDataSourceProvider = Provider<PreferencesLocalDataSource>((ref) {
  return PreferencesLocalDataSource(ref.watch(isarProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepositoryImpl(ref.watch(preferencesLocalDataSourceProvider));
});
