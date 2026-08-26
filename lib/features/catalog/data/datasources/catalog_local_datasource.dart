import 'package:isar_community/isar.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/canonical_item_model.dart';

/// Every raw Isar query against the canonical catalog.
class CatalogLocalDataSource {
  final Isar _isar;
  CatalogLocalDataSource(this._isar);

  Future<int> count() => _isar.canonicalItemModels.count();

  Future<List<CanonicalItemModel>> getAll() {
    try {
      return _isar.canonicalItemModels.where().findAll();
    } catch (e) {
      throw StorageException('Failed to load catalog', cause: e);
    }
  }

  Future<CanonicalItemModel?> getById(int isarId) =>
      _isar.canonicalItemModels.get(isarId);

  Future<CanonicalItemModel?> getBySlug(String slug) =>
      _isar.canonicalItemModels.filter().slugEqualTo(slug).findFirst();

  /// Upsert by slug. `replace: true` on the unique slug index means a re-seed
  /// updates names and aliases in place instead of duplicating rows.
  Future<void> putAll(List<CanonicalItemModel> items) async {
    try {
      await _isar.writeTxn(() => _isar.canonicalItemModels.putAll(items));
    } catch (e) {
      throw StorageException('Failed to write catalog', cause: e);
    }
  }
}
