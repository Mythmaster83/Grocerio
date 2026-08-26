import '../../../../core/utils/result.dart';
import '../entities/grocery_item.dart';
import '../entities/grocery_list.dart';

/// Domain-facing contract. Presentation depends on THIS, never on the Isar
/// implementation directly — that's what makes "swap Isar for X later" a
/// one-file change instead of a rewrite.
abstract class ListsRepository {
  /// Live stream of all lists, sorted by scheduledFor. Backs the
  /// "real-time updates" requirement: any write anywhere re-emits here.
  Stream<List<GroceryList>> watchLists();

  Stream<GroceryList?> watchList(String listId);

  Future<Result<List<GroceryList>>> getAllLists();

  Future<Result<GroceryList?>> getList(String listId);

  Future<Result<GroceryList>> createList({
    required String name,
    required DateTime scheduledFor,
    required int frequencyIndex,
  });

  /// Rename, reschedule and/or change how often a list repeats. Every field is
  /// optional so the caller can change just one without reading the list first.
  Future<Result<void>> updateList({
    required String listId,
    String? name,
    DateTime? scheduledFor,
    int? frequencyIndex,
  });

  Future<Result<void>> deleteList(String listId);

  /// [customUnit] is required when [unitIndex] points at `ItemUnit.custom`
  /// and ignored otherwise.
  Future<Result<GroceryItem>> addItem({
    required String listId,
    required String name,
    required double quantity,
    required int unitIndex,
    String? customUnit,
  });

  /// Distinct item names matching [query] (case-insensitive prefix), newest-first feel via sort.
  Future<Result<List<String>>> suggestItemNames(String query, {int limit = 8});

  Future<Result<void>> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    int? unitIndex,
    String? customUnit,
    bool? isChecked,

    /// Explicit catalog link, used when the user picks the product by hand
    /// because automatic resolution found nothing. A rename resolves the id
    /// automatically and ignores this.
    int? canonicalItemId,
  });

  Future<Result<void>> deleteItem({
    required String listId,
    required String itemId,
  });

  /// Uncheck all items, set next [newScheduledFor], clear miss flag.
  Future<Result<void>> finalizeShoppingTrip({
    required String listId,
    required DateTime newScheduledFor,
  });

  Future<Result<void>> applyScheduleReconciliation({
    required String listId,
    required DateTime scheduledFor,
    required DateTime lastMissedOn,
  });

  Future<Result<void>> flagMissedDate({
    required String listId,
    required DateTime lastMissedOn,
  });

  Future<Result<void>> clearLastMissedOn(String listId);
}
