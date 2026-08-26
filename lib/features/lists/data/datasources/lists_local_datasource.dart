import 'package:isar_community/isar.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/grocery_item_model.dart';
import '../models/grocery_list_model.dart';

/// Owns every raw Isar query. Nothing above this layer knows Isar exists.
/// Throws [StorageException] on failure â€” the repository above is
/// responsible for catching it and converting to Result<T>/AppFailure.
class ListsLocalDataSource {
  final Isar _isar;
  final Uuid _uuid;

  ListsLocalDataSource(this._isar, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  /// Every read here excludes tombstoned rows. Deleted lists are kept on disk
  /// until sync has carried the deletion elsewhere, so "deleted" is a filter
  /// condition in this layer, not an absent row.
  Stream<List<GroceryListModel>> watchLists() {
    return _isar.groceryListModels
        .where()
        .watch(fireImmediately: true)
        .asyncMap(
          (_) => _isar.groceryListModels
              .filter()
              .deletedAtIsNull()
              .sortByScheduledFor()
              .findAll(),
        );
  }

  Stream<GroceryListModel?> watchList(String publicId) {
    return _isar.groceryListModels
        .filter()
        .publicIdEqualTo(publicId)
        .watch(fireImmediately: true)
        .asyncMap((_) => _findByPublicId(publicId));
  }

  Future<GroceryListModel?> _findByPublicId(String publicId) => _isar
      .groceryListModels
      .filter()
      .publicIdEqualTo(publicId)
      .deletedAtIsNull()
      .findFirst();

  Future<List<GroceryListModel>> getAllLists() =>
      _isar.groceryListModels.filter().deletedAtIsNull().findAll();

  Future<GroceryListModel?> getList(String publicId) =>
      _findByPublicId(publicId);

  /// Deep-copy embedded items. Isar can corrupt object-lists if a parent row
  /// is `put` after mutating scalars without reassigning `items`.
  List<GroceryItemModel> _cloneItems(
    List<GroceryItemModel> source, {
    bool uncheckAll = false,
    DateTime? updatedAt,
  }) {
    final now = updatedAt ?? DateTime.now();
    return [
      for (final i in source)
        GroceryItemModel()
          ..id = i.id
          ..name = i.name
          ..quantity = i.quantity
          ..unit = i.unit
          ..customUnit = i.customUnit
          ..canonicalItemId = i.canonicalItemId
          ..deletedAt = i.deletedAt
          ..isChecked = uncheckAll ? false : i.isChecked
          ..updatedAt = uncheckAll ? now : i.updatedAt,
    ];
  }

  /// Replace a list row by rewriting every field (keeps [isarId]).
  Future<void> _putListCopy(
    GroceryListModel existing, {
    String? name,
    ScheduleFrequencyDb? frequency,
    DateTime? scheduledFor,
    DateTime? lastMissedOn,
    bool clearLastMissedOn = false,
    DateTime? deletedAt,
    List<GroceryItemModel>? items,
  }) async {
    final copy = GroceryListModel()
      ..isarId = existing.isarId
      ..publicId = existing.publicId
      ..name = name ?? existing.name
      ..frequency = frequency ?? existing.frequency
      ..scheduledFor = scheduledFor ?? existing.scheduledFor
      ..createdAt = existing.createdAt
      ..lastMissedOn =
          clearLastMissedOn ? null : (lastMissedOn ?? existing.lastMissedOn)
      // Every write goes through here, so this is the one place that can
      // guarantee updatedAt actually tracks mutations for sync.
      ..updatedAt = DateTime.now()
      ..deletedAt = deletedAt ?? existing.deletedAt
      ..ownerId = existing.ownerId
      ..items = items ?? _cloneItems(existing.items);
    await _isar.groceryListModels.put(copy);
  }

  Future<List<String>> suggestItemNames(String queryLower, {int limit = 8}) async {
    try {
      final lists = await getAllLists();
      final seen = <String>{};
      final matches = <String>[];
      for (final list in lists) {
        for (final item in list.items) {
          if (item.deletedAt != null) continue;
          final name = item.name.trim();
          if (name.isEmpty) continue;
          final key = name.toLowerCase();
          if (!key.startsWith(queryLower)) continue;
          if (seen.contains(key)) continue;
          seen.add(key);
          matches.add(name);
          if (matches.length >= limit) return matches;
        }
      }
      return matches;
    } catch (e) {
      throw StorageException('Failed to suggest item names', cause: e);
    }
  }

  Future<GroceryListModel> createList({
    required String name,
    required DateTime scheduledFor,
    required ScheduleFrequencyDb frequency,
  }) async {
    final model = GroceryListModel()
      ..publicId = _uuid.v4()
      ..name = name
      ..frequency = frequency
      ..scheduledFor = scheduledFor
      ..createdAt = DateTime.now()
      ..lastMissedOn = null
      ..updatedAt = DateTime.now()
      ..items = [];
    try {
      await _isar.writeTxn(() => _isar.groceryListModels.put(model));
      return model;
    } catch (e) {
      throw StorageException('Failed to create list', cause: e);
    }
  }

  /// Rename and/or reschedule a list. Setting a new [scheduledFor] clears the
  /// missed-date flag: the user has just chosen the date on purpose, so the
  /// old "you skipped this" notice is stale by definition.
  Future<void> updateListDetails({
    required String listPublicId,
    String? name,
    DateTime? scheduledFor,
    ScheduleFrequencyDb? frequency,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(
          model,
          name: name,
          scheduledFor: scheduledFor,
          frequency: frequency,
          clearLastMissedOn: scheduledFor != null,
        );
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to update list', cause: e);
    }
  }

  /// Tombstones the list instead of removing the row. A hard delete cannot be
  /// synced: the other device has no way to tell "deleted here" from "not
  /// created here yet" and would simply push the list back.
  Future<void> deleteList(String publicId) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(publicId);
        if (model == null) return;
        await _putListCopy(model, deletedAt: DateTime.now());
      });
    } catch (e) {
      throw StorageException('Failed to delete list', cause: e);
    }
  }

  Future<GroceryItemModel> addItem({
    required String listPublicId,
    required String name,
    required double quantity,
    required ItemUnitDb unit,
    String? customUnit,
    int? canonicalItemId,
  }) async {
    final item = GroceryItemModel()
      ..id = _uuid.v4()
      ..name = name
      ..quantity = quantity
      ..unit = unit
      ..customUnit = unit == ItemUnitDb.custom ? customUnit : null
      ..canonicalItemId = canonicalItemId
      ..isChecked = false
      ..updatedAt = DateTime.now();

    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(
          model,
          items: [..._cloneItems(model.items), item],
        );
      });
      return item;
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to add item', cause: e);
    }
  }

  Future<void> updateItem({
    required String listPublicId,
    required String itemId,
    String? name,
    double? quantity,
    ItemUnitDb? unit,
    String? customUnit,
    int? canonicalItemId,
    bool? isChecked,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        final items = _cloneItems(model.items);
        final idx = items.indexWhere((i) => i.id == itemId);
        if (idx == -1) throw StorageException('Item not found: $itemId');

        final existing = items[idx];
        final nextUnit = unit ?? existing.unit;
        items[idx] = GroceryItemModel()
          ..id = existing.id
          ..name = name ?? existing.name
          ..quantity = quantity ?? existing.quantity
          ..unit = nextUnit
          // Switching away from a custom unit must drop its stale label,
          // otherwise "2 kg" would still carry a leftover "bunch".
          ..customUnit = nextUnit == ItemUnitDb.custom
              ? (customUnit ?? existing.customUnit)
              : null
          // A rename re-resolves the catalog match, so the caller passes the
          // new id; absent that, keep whatever was already resolved.
          ..canonicalItemId = canonicalItemId ?? existing.canonicalItemId
          ..deletedAt = existing.deletedAt
          ..isChecked = isChecked ?? existing.isChecked
          ..updatedAt = DateTime.now();

        await _putListCopy(model, items: items);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to update item', cause: e);
    }
  }

  /// Tombstones the item; see [deleteList] for why the row survives.
  /// `GroceryListModel.toDomain` filters tombstones out of the UI.
  Future<void> deleteItem({
    required String listPublicId,
    required String itemId,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        final now = DateTime.now();
        final items = _cloneItems(model.items);
        final idx = items.indexWhere((i) => i.id == itemId);
        if (idx == -1) return;
        items[idx]
          ..deletedAt = now
          ..updatedAt = now;
        await _putListCopy(model, items: items);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete item', cause: e);
    }
  }

  /// Uncheck every item, advance [scheduledFor], clear miss flag â€” one txn.
  Future<void> finalizeShoppingTrip({
    required String listPublicId,
    required DateTime newScheduledFor,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(
          model,
          scheduledFor: newScheduledFor,
          clearLastMissedOn: true,
          items: _cloneItems(model.items, uncheckAll: true),
        );
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to complete shopping', cause: e);
    }
  }

  Future<void> applyScheduleReconciliation({
    required String listPublicId,
    required DateTime scheduledFor,
    required DateTime lastMissedOn,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(
          model,
          scheduledFor: scheduledFor,
          lastMissedOn: lastMissedOn,
        );
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to reconcile schedule', cause: e);
    }
  }

  Future<void> flagMissedDate({
    required String listPublicId,
    required DateTime lastMissedOn,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(model, lastMissedOn: lastMissedOn);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to flag missed date', cause: e);
    }
  }

  Future<void> clearLastMissedOn(String listPublicId) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        await _putListCopy(model, clearLastMissedOn: true);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to clear missed date', cause: e);
    }
  }
}
