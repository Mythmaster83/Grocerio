import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/backend/supabase_config.dart';
import '../../../../core/di/isar_provider.dart';
import '../../data/datasources/stores_local_datasource.dart';
import '../../data/repositories/stores_repository_impl.dart';
import '../../data/services/tracked_stores_sync_service.dart';
import '../../domain/entities/store.dart';
import '../../domain/repositories/stores_repository.dart';

final storesLocalDataSourceProvider = Provider<StoresLocalDataSource>((ref) {
  return StoresLocalDataSource(ref.watch(isarProvider));
});

final trackedStoresSyncServiceProvider =
    Provider<TrackedStoresSyncService>((ref) {
  return TrackedStoresSyncService(
    SupabaseConfig.clientOrNull,
    ref.watch(storesLocalDataSourceProvider),
  );
});

final storesRepositoryProvider = Provider<StoresRepository>((ref) {
  return StoresRepositoryImpl(
    ref.watch(storesLocalDataSourceProvider),
    ref.watch(trackedStoresSyncServiceProvider),
  );
});

/// Not autoDispose: the store list is tiny, read by several screens, and
/// re-subscribing on every navigation would flash empty filter chips.
final storesStreamProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(storesRepositoryProvider).watchStores();
});

/// Stores the user shops at. The report sheet defaults to the first of these.
final trackedStoresProvider = Provider<List<Store>>((ref) {
  final stores = ref.watch(storesStreamProvider).valueOrNull ?? const <Store>[];
  return stores.where((s) => s.trackedByUser).toList(growable: false);
});
