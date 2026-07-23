import '../../../../core/errors/exceptions.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/grocery_item.dart';
import '../../domain/entities/grocery_list.dart';
import '../../domain/repositories/lists_repository.dart';
import '../datasources/lists_local_datasource.dart';
import '../models/grocery_item_model.dart';
import '../models/grocery_list_model.dart';

class ListsRepositoryImpl implements ListsRepository {
  final ListsLocalDataSource _local;

  ListsRepositoryImpl(this._local);

  @override
  Stream<List<GroceryList>> watchLists() =>
      _local.watchLists().map((models) => models.map((m) => m.toDomain()).toList());

  @override
  Stream<GroceryList?> watchList(String listId) =>
      _local.watchList(listId).map((m) => m?.toDomain());

  @override
  Future<Result<GroceryList>> createList({
    required String name,
    required DateTime scheduledFor,
    required int frequencyIndex,
  }) async {
    final cleanName = InputSanitizer.sanitizeFreeText(
      name,
      maxLength: InputSanitizer.maxListNameLength,
    );
    if (cleanName.isEmpty) {
      return const Result.err(ValidationFailure('List name cannot be empty.'));
    }
    try {
      final model = await _local.createList(
        name: cleanName,
        scheduledFor: scheduledFor,
        frequency: ScheduleFrequencyDb.values[frequencyIndex],
      );
      return Result.ok(model.toDomain());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not create the list.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteList(String listId) async {
    try {
      await _local.deleteList(listId);
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not delete the list.', cause: e));
    }
  }

  @override
  Future<Result<GroceryItem>> addItem({
    required String listId,
    required String name,
    required double quantity,
    required int unitIndex,
    String? imageUrl,
  }) async {
    final cleanName = InputSanitizer.sanitizeFreeText(
      name,
      maxLength: InputSanitizer.maxItemNameLength,
    );
    if (cleanName.isEmpty) {
      return const Result.err(ValidationFailure('Item name cannot be empty.'));
    }
    if (quantity <= 0) {
      return const Result.err(ValidationFailure('Quantity must be greater than zero.'));
    }
    try {
      final model = await _local.addItem(
        listPublicId: listId,
        name: cleanName,
        quantity: quantity,
        unit: ItemUnitDb.values[unitIndex],
        imageUrl: imageUrl
      );
      return Result.ok(model.toDomain());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not add the item.', cause: e));
    }
  }

  @override
  Future<Result<void>> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    int? unitIndex,
    bool? isChecked,
  }) async {
    if (quantity != null && quantity < 0) {
      return const Result.err(ValidationFailure('Quantity cannot be negative.'));
    }
    final cleanName = name == null
        ? null
        : InputSanitizer.sanitizeFreeText(name, maxLength: InputSanitizer.maxItemNameLength);
    if (cleanName != null && cleanName.isEmpty) {
      return const Result.err(ValidationFailure('Item name cannot be empty.'));
    }
    try {
      await _local.updateItem(
        listPublicId: listId,
        itemId: itemId,
        name: cleanName,
        quantity: quantity,
        unit: unitIndex == null ? null : ItemUnitDb.values[unitIndex],
        isChecked: isChecked,
      );
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not update the item.', cause: e));
    }
  }

  @override
  Future<Result<void>> deleteItem({required String listId, required String itemId}) async {
    try {
      await _local.deleteItem(listPublicId: listId, itemId: itemId);
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not delete the item.', cause: e));
    }
  }
}
