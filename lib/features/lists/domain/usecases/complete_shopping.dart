import '../../../../core/utils/result.dart';
import '../entities/grocery_list.dart';
import '../repositories/lists_repository.dart';
import '../schedule_rules.dart';

/// Completes a shopping trip: uncheck all + advance date, or delete one-time.
class CompleteShopping {
  final ListsRepository _repository;
  CompleteShopping(this._repository);

  Future<Result<void>> call(String listId) async {
    final loaded = await _repository.getList(listId);
    if (loaded is Err<GroceryList?>) {
      return Result.err(loaded.failure);
    }
    final list = (loaded as Ok<GroceryList?>).value;
    if (list == null) {
      return const Result.err(NotFoundFailure('List not found.'));
    }

    final plan = planCompleteShopping(list);
    return switch (plan) {
      DeleteListPlan() => _repository.deleteList(listId),
      AdvanceListPlan(:final newScheduledFor) =>
        _repository.finalizeShoppingTrip(
          listId: listId,
          newScheduledFor: newScheduledFor,
        ),
    };
  }
}
