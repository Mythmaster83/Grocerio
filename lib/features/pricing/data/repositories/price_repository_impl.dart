import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../../stores/domain/entities/store.dart';
import '../../../stores/domain/repositories/stores_repository.dart';
import '../../domain/entities/store_price.dart';
import '../../domain/price_selection.dart';
import '../../domain/repositories/price_repository.dart';
import '../datasources/price_local_datasource.dart';

class PriceRepositoryImpl implements PriceRepository {
  final PriceLocalDataSource _local;
  final StoresRepository _stores;

  PriceRepositoryImpl(this._local, this._stores);

  Future<List<Store>> _loadStores() async {
    final result = await _stores.getStores();
    return result.when(ok: (stores) => stores, err: (_) => const <Store>[]);
  }

  @override
  Stream<PriceComparison> watchCheapestFor(
    int canonicalItemId, {
    Set<int>? storeIdsFilter,
  }) {
    return _local.watchReports().asyncMap((_) async {
      try {
        return await _buildFor(canonicalItemId, storeIdsFilter: storeIdsFilter);
      } on StorageException catch (e, st) {
        logger.error(e.message, e.cause, st);
        // A failed read must not kill the stream, or the tile stops updating
        // for the rest of the session.
        return PriceComparison.empty(canonicalItemId);
      }
    });
  }

  @override
  Future<Result<Map<int, PriceComparison>>> comparisonsFor(
    List<int> canonicalItemIds, {
    Set<int>? storeIdsFilter,
  }) async {
    if (canonicalItemIds.isEmpty) return const Result.ok({});
    try {
      final stores = await _loadStores();
      final reports = (await _local.reportsForItems(canonicalItemIds))
          .map((m) => m.toDomain())
          .toList(growable: false);
      final now = DateTime.now();

      return Result.ok({
        for (final id in canonicalItemIds)
          id: buildPriceComparison(
            canonicalItemId: id,
            reports: reports,
            stores: stores,
            now: now,
            storeIdsFilter: storeIdsFilter,
          ),
      });
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load prices', cause: e));
    }
  }

  Future<PriceComparison> _buildFor(
    int canonicalItemId, {
    Set<int>? storeIdsFilter,
  }) async {
    final stores = await _loadStores();
    final reports = (await _local.reportsForItem(canonicalItemId))
        .map((m) => m.toDomain())
        .toList(growable: false);

    return buildPriceComparison(
      canonicalItemId: canonicalItemId,
      reports: reports,
      stores: stores,
      now: DateTime.now(),
      storeIdsFilter: storeIdsFilter,
    );
  }
}
