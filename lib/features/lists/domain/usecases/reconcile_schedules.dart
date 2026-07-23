import '../../../../core/utils/result.dart';
import '../entities/grocery_list.dart';
import '../repositories/lists_repository.dart';
import '../schedule_rules.dart';

/// On app open: roll overdue recurring dates forward and flag missed dates.
class ReconcileSchedules {
  final ListsRepository _repository;
  ReconcileSchedules(this._repository);

  Future<Result<void>> call({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final loaded = await _repository.getAllLists();
    if (loaded is Err<List<GroceryList>>) {
      return Result.err(loaded.failure);
    }
    final lists = (loaded as Ok<List<GroceryList>>).value;

    for (final list in lists) {
      final plan = planReconciliation(list, clock);
      final Result<void> result = switch (plan) {
        ReconcileNoOp() => const Result.ok(null),
        ReconcileFlagOnly(:final lastMissedOn) =>
          await _repository.flagMissedDate(
            listId: list.id,
            lastMissedOn: lastMissedOn,
          ),
        ReconcileAdvanceAndFlag(
          :final newScheduledFor,
          :final lastMissedOn,
        ) =>
          await _repository.applyScheduleReconciliation(
            listId: list.id,
            scheduledFor: newScheduledFor,
            lastMissedOn: lastMissedOn,
          ),
      };
      if (result is Err<void>) {
        return Result.err(result.failure);
      }
    }
    return const Result.ok(null);
  }
}
