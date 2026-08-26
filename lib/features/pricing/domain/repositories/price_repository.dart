import '../../../../core/utils/result.dart';
import '../entities/store_price.dart';

abstract class PriceRepository {
  /// Best available price per store for one item, re-emitted whenever any
  /// report changes so a price reported from one screen updates every other
  /// screen showing that item.
  Stream<PriceComparison> watchCheapestFor(
    int canonicalItemId, {
    Set<int>? storeIdsFilter,
  });

  /// Batch variant for screens showing many items at once.
  Future<Result<Map<int, PriceComparison>>> comparisonsFor(
    List<int> canonicalItemIds, {
    Set<int>? storeIdsFilter,
  });
}
