import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/grocery_item_model.dart';
import '../models/grocery_list_model.dart';

/// Owns every raw Isar query. Nothing above this layer knows Isar exists.
/// Throws [StorageException] on failure — the repository above is
/// responsible for catching it and converting to Result<T>/AppFailure.
class ListsLocalDataSource {
  final Isar _isar;
  final Uuid _uuid;

  ListsLocalDataSource(this._isar, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Stream<List<GroceryListModel>> watchLists() {
    return _isar.groceryListModels
        .where()
        .watch(fireImmediately: true)
        .asyncMap((_) => _isar.groceryListModels.where().sortByScheduledFor().findAll());
  }

  Stream<GroceryListModel?> watchList(String publicId) {
    return _isar.groceryListModels
        .filter()
        .publicIdEqualTo(publicId)
        .watch(fireImmediately: true)
        .asyncMap((_) => _findByPublicId(publicId));
  }

  Future<GroceryListModel?> _findByPublicId(String publicId) =>
      _isar.groceryListModels.filter().publicIdEqualTo(publicId).findFirst();

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
      ..items = [];
    try {
      await _isar.writeTxn(() => _isar.groceryListModels.put(model));
      return model;
    } catch (e) {
      throw StorageException('Failed to create list', cause: e);
    }
  }

  Future<void> deleteList(String publicId) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(publicId);
        if (model != null) await _isar.groceryListModels.delete(model.isarId);
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
    String? imageUrl,
  }) async {
    final item = GroceryItemModel()
      ..id = _uuid.v4()
      ..name = name
      ..quantity = quantity
      ..unit = unit
      ..isChecked = false
      ..imageUrl = imageUrl
      ..updatedAt = DateTime.now();

    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        model.items = [...model.items, item];
        await _isar.groceryListModels.put(model);
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
    bool? isChecked,
  }) async {
    try {
      await _isar.writeTxn(() async {
        final model = await _findByPublicId(listPublicId);
        if (model == null) {
          throw StorageException('List not found: $listPublicId');
        }
        final items = [...model.items];
        final idx = items.indexWhere((i) => i.id == itemId);
        if (idx == -1) throw StorageException('Item not found: $itemId');

        final existing = items[idx];
        items[idx] = GroceryItemModel()
          ..id = existing.id
          ..name = name ?? existing.name
          ..quantity = quantity ?? existing.quantity
          ..unit = unit ?? existing.unit
          ..isChecked = isChecked ?? existing.isChecked
          ..imageUrl = existing.imageUrl
          ..updatedAt = DateTime.now();

        model.items = items;
        await _isar.groceryListModels.put(model);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to update item', cause: e);
    }
  }

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
        model.items = model.items.where((i) => i.id != itemId).toList();
        await _isar.groceryListModels.put(model);
      });
    } catch (e) {
      if (e is StorageException) rethrow;
      throw StorageException('Failed to delete item', cause: e);
    }
  }
}
