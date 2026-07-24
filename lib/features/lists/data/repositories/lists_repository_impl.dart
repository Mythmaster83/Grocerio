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
  Future<Result<List<GroceryList>>> getAllLists() async {
    try {
      final models = await _local.getAllLists();
      return Result.ok(models.map((m) => m.toDomain()).toList());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load lists.', cause: e));
    }
  }

  @override
  Future<Result<GroceryList?>> getList(String listId) async {
    try {
      final model = await _local.getList(listId);
      return Result.ok(model?.toDomain());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load the list.', cause: e));
    }
  }

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
    String? imagePhotographer,
    String? imagePhotographerUrl,
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
        imageUrl: imageUrl,
        imagePhotographer: imagePhotographer,
        imagePhotographerUrl: imagePhotographerUrl,
      );
      return Result.ok(model.toDomain());
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not add the item.', cause: e));
    }
  }

  @override
  Future<Result<List<String>>> suggestItemNames(String query, {int limit = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const Result.ok([]);
    try {
      final names = await _local.suggestItemNames(q, limit: limit);
      return Result.ok(names);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not load suggestions.', cause: e));
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

  @override
  Future<Result<void>> finalizeShoppingTrip({
    required String listId,
    required DateTime newScheduledFor,
  }) async {
    try {
      await _local.finalizeShoppingTrip(
        listPublicId: listId,
        newScheduledFor: newScheduledFor,
      );
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(
        StorageFailure('Could not complete shopping.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> applyScheduleReconciliation({
    required String listId,
    required DateTime scheduledFor,
    required DateTime lastMissedOn,
  }) async {
    try {
      await _local.applyScheduleReconciliation(
        listPublicId: listId,
        scheduledFor: scheduledFor,
        lastMissedOn: lastMissedOn,
      );
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(
        StorageFailure('Could not update the schedule.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> flagMissedDate({
    required String listId,
    required DateTime lastMissedOn,
  }) async {
    try {
      await _local.flagMissedDate(
        listPublicId: listId,
        lastMissedOn: lastMissedOn,
      );
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(
        StorageFailure('Could not flag the missed date.', cause: e),
      );
    }
  }

  @override
  Future<Result<void>> clearLastMissedOn(String listId) async {
    try {
      await _local.clearLastMissedOn(listId);
      return const Result.ok(null);
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(
        StorageFailure('Could not clear the missed-date notice.', cause: e),
      );
    }
  }
}
