import 'package:isar_community/isar.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/price_report_model.dart';

class PriceLocalDataSource {
  final Isar _isar;
  PriceLocalDataSource(this._isar);

  /// Live-but-coarse: fires on any report change, and callers re-query. Fine at
  /// this scale, and it means a newly submitted price appears on every screen
  /// showing that item without any manual invalidation.
  Stream<void> watchReports() =>
      _isar.priceReportModels.where().watch(fireImmediately: true);

  Future<List<PriceReportModel>> reportsForItem(int canonicalItemId) async {
    try {
      return await _isar.priceReportModels
          .filter()
          .canonicalItemIdEqualTo(canonicalItemId)
          .deletedAtIsNull()
          .findAll();
    } catch (e) {
      throw StorageException('Failed to load price reports', cause: e);
    }
  }

  Future<List<PriceReportModel>> reportsForItems(List<int> canonicalItemIds) async {
    if (canonicalItemIds.isEmpty) return const [];
    try {
      return await _isar.priceReportModels
          .filter()
          .anyOf(canonicalItemIds, (q, id) => q.canonicalItemIdEqualTo(id))
          .deletedAtIsNull()
          .findAll();
    } catch (e) {
      throw StorageException('Failed to load price reports', cause: e);
    }
  }

  Future<void> put(PriceReportModel report) async {
    try {
      await _isar.writeTxn(() => _isar.priceReportModels.put(report));
    } catch (e) {
      throw StorageException('Failed to save price report', cause: e);
    }
  }

  Future<void> putAll(List<PriceReportModel> reports) async {
    if (reports.isEmpty) return;
    try {
      await _isar.writeTxn(() => _isar.priceReportModels.putAll(reports));
    } catch (e) {
      throw StorageException('Failed to save price reports', cause: e);
    }
  }

  /// Includes tombstoned rows. Sync needs the full set so a suppression can
  /// still be pushed; the UI queries never use this.
  Future<List<PriceReportModel>> allReports() async {
    try {
      return await _isar.priceReportModels.where().findAll();
    } catch (e) {
      throw StorageException('Failed to load price reports', cause: e);
    }
  }
}
