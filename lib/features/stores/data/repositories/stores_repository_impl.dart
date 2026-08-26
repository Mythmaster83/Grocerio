import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/store.dart';
import '../../domain/repositories/stores_repository.dart';
import '../datasources/stores_local_datasource.dart';
import '../services/tracked_stores_sync_service.dart';

class StoresRepositoryImpl implements StoresRepository {
  final StoresLocalDataSource _local;
  final TrackedStoresSyncService _trackedSync;

  StoresRepositoryImpl(this._local, this._trackedSync);

  @override
  Stream<List<Store>> watchStores() => _local
      .watchStores()
      .map((models) => models.map((m) => m.toDomain()).toList(growable: false));

  @override
  Future<Result<List<Store>>> getStores() async {
    try {
      final models = await _local.getAll();
      return Result.ok(models.map((m) => m.toDomain()).toList(growable: false));
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load stores', cause: e));
    }
  }

  @override
  Future<Result<void>> setTracked({
    required int storeId,
    required bool tracked,
  }) async {
    try {
      final existing = await _local.getById(storeId);
      await _local.setTracked(isarId: storeId, tracked: tracked);
      if (existing != null) {
        await _trackedSync.pushTrackedChange(
          storeSlug: existing.slug,
          tracked: tracked,
        );
      }
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not update store', cause: e));
    }
  }

  @override
  Future<Result<void>> syncTrackedWithAccount() => _trackedSync.sync();
}
