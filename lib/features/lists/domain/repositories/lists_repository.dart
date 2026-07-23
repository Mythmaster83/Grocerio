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

  Future<Result<GroceryList>> createList({
    required String name,
    required DateTime scheduledFor,
    required int frequencyIndex,
  });

  Future<Result<void>> deleteList(String listId);

  Future<Result<GroceryItem>> addItem({
    required String listId,
    required String name,
    required double quantity,
    required int unitIndex,
    String? imageUrl,
  });

  Future<Result<void>> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    int? unitIndex,
    bool? isChecked,
  });

  Future<Result<void>> deleteItem({
    required String listId,
    required String itemId,
  });
}
