import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/isar_provider.dart';
import '../../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../../data/datasources/catalog_local_datasource.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/services/catalog_seed_service.dart';
import '../../domain/repositories/catalog_repository.dart';

final catalogLocalDataSourceProvider = Provider<CatalogLocalDataSource>((ref) {
  return CatalogLocalDataSource(ref.watch(isarProvider));
});

/// Not autoDispose: the implementation caches the whole catalog in memory, and
/// disposing it would throw that cache away on every navigation.
final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepositoryImpl(ref.watch(catalogLocalDataSourceProvider));
});

final catalogSeedServiceProvider = Provider<CatalogSeedService>((ref) {
  return CatalogSeedService(
    catalog: ref.watch(catalogLocalDataSourceProvider),
    stores: ref.watch(storesLocalDataSourceProvider),
    preferences: PreferencesLocalDataSource(ref.watch(isarProvider)),
    bundle: rootBundle,
  );
});
