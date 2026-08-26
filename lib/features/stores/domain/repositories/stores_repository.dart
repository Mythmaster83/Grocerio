import '../../../../core/utils/result.dart';
import '../entities/store.dart';

abstract class StoresRepository {
  /// Live store list, so toggling "tracked" updates every dependent screen
  /// (report sheet default, comparison filters) without manual refreshes.
  Stream<List<Store>> watchStores();

  Future<Result<List<Store>>> getStores();

  Future<Result<void>> setTracked({
    required int storeId,
    required bool tracked,
  });

  /// Restore tracked flags from the signed-in account (no-op when offline).
  Future<Result<void>> syncTrackedWithAccount();
}
