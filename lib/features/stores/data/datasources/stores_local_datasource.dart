import 'package:isar_community/isar.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/store_model.dart';

class StoresLocalDataSource {
  final Isar _isar;
  StoresLocalDataSource(this._isar);

  Stream<List<StoreModel>> watchStores() {
    return _isar.storeModels
        .where()
        .watch(fireImmediately: true)
        .asyncMap((_) => _isar.storeModels.where().sortByName().findAll());
  }

  Future<List<StoreModel>> getAll() => _isar.storeModels.where().sortByName().findAll();

  Future<StoreModel?> getById(int isarId) => _isar.storeModels.get(isarId);

  Future<StoreModel?> getBySlug(String slug) =>
      _isar.storeModels.filter().slugEqualTo(slug).findFirst();

  Future<void> putAll(List<StoreModel> stores) async {
    try {
      await _isar.writeTxn(() => _isar.storeModels.putAll(stores));
    } catch (e) {
      throw StorageException('Failed to write stores', cause: e);
    }
  }

  /// Wipe the local store directory (used when re-seeding a new catalog version).
  Future<void> clearAll() async {
    try {
      await _isar.writeTxn(() => _isar.storeModels.clear());
    } catch (e) {
      throw StorageException('Failed to clear stores', cause: e);
    }
  }

  /// Seeding must not clobber a user's tracking choices, so the seeder reads
  /// the existing row first and only writes name/slug.
  Future<void> setTracked({required int isarId, required bool tracked}) async {
    try {
      await _isar.writeTxn(() async {
        final existing = await _isar.storeModels.get(isarId);
        if (existing == null) return;
        existing.trackedByUser = tracked;
        await _isar.storeModels.put(existing);
      });
    } catch (e) {
      throw StorageException('Failed to update store', cause: e);
    }
  }

  /// Apply a full set of tracked slugs (account sync). Unlisted stores become
  /// untracked; unknown slugs are ignored.
  Future<void> setTrackedBySlugs(Set<String> trackedSlugs) async {
    try {
      await _isar.writeTxn(() async {
        final all = await _isar.storeModels.where().findAll();
        for (final store in all) {
          final shouldTrack = trackedSlugs.contains(store.slug);
          if (store.trackedByUser == shouldTrack) continue;
          store.trackedByUser = shouldTrack;
          await _isar.storeModels.put(store);
        }
      });
    } catch (e) {
      throw StorageException('Failed to apply tracked stores', cause: e);
    }
  }
}
