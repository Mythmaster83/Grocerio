import 'package:isar_community/isar.dart';
import '../../../core/errors/exceptions.dart';
import '../../lists/data/models/grocery_list_model.dart';

/// Isar access for sync only.
///
/// Separate from `ListsLocalDataSource` because that class exists to serve the
/// UI and therefore hides tombstones, while sync needs to see exactly the rows
/// the UI must not: deleted lists, deleted items, and ownership.
class SyncLocalDataSource {
  final Isar _isar;

  SyncLocalDataSource(this._isar);

  /// Includes tombstoned rows.
  Future<List<GroceryListModel>> allLists() =>
      _isar.groceryListModels.where().findAll();

  Future<GroceryListModel?> findByPublicId(String publicId) =>
      _isar.groceryListModels.filter().publicIdEqualTo(publicId).findFirst();

  /// Attaches pre-existing local lists to the account on first sign-in, so a
  /// user who used the app offline for months doesn't lose that history the
  /// moment they create an account.
  Future<int> claimUnownedLists(String userId) async {
    try {
      return await _isar.writeTxn(() async {
        final unowned =
            await _isar.groceryListModels.filter().ownerIdIsNull().findAll();
        for (final list in unowned) {
          list.ownerId = userId;
        }
        if (unowned.isNotEmpty) {
          await _isar.groceryListModels.putAll(unowned);
        }
        return unowned.length;
      });
    } catch (e) {
      throw StorageException('Failed to claim local lists', cause: e);
    }
  }

  /// Writes merged rows in one transaction so a partial pull can't leave the
  /// database half-updated.
  Future<void> putMerged(List<GroceryListModel> lists) async {
    if (lists.isEmpty) return;
    try {
      await _isar.writeTxn(() => _isar.groceryListModels.putAll(lists));
    } catch (e) {
      throw StorageException('Failed to apply remote lists', cause: e);
    }
  }

  /// Hard-deletes tombstones old enough that every device has certainly seen
  /// them. Without this, tombstones accumulate forever.
  Future<int> purgeTombstones(DateTime cutoff) async {
    try {
      return await _isar.writeTxn(() async {
        final stale = await _isar.groceryListModels
            .filter()
            .deletedAtIsNotNull()
            .deletedAtLessThan(cutoff)
            .findAll();
        if (stale.isEmpty) return 0;
        await _isar.groceryListModels
            .deleteAll(stale.map((l) => l.isarId).toList(growable: false));
        return stale.length;
      });
    } catch (e) {
      throw StorageException('Failed to purge tombstones', cause: e);
    }
  }
}
