import '../../../../core/utils/result.dart';
import '../entities/grocery_list.dart';
import '../repositories/lists_repository.dart';
import '../schedule_rules.dart';

/// Outcome of reconciling one list — used by presentation to fire notifications.
class ReconcileChange {
  final GroceryList list;
  final bool missed;
  final bool advanced;

  const ReconcileChange({
    required this.list,
    required this.missed,
    required this.advanced,
  });
}

/// On app open: roll overdue recurring dates forward and flag missed dates.
class ReconcileSchedules {
  final ListsRepository _repository;
  ReconcileSchedules(this._repository);

  Future<Result<List<ReconcileChange>>> call({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final loaded = await _repository.getAllLists();
    if (loaded is Err<List<GroceryList>>) {
      return Result.err(loaded.failure);
    }
    final lists = (loaded as Ok<List<GroceryList>>).value;
    final changes = <ReconcileChange>[];

    for (final list in lists) {
      final plan = planReconciliation(list, clock);
      switch (plan) {
        case ReconcileNoOp():
          break;
        case ReconcileFlagOnly(:final lastMissedOn):
          final result = await _repository.flagMissedDate(
            listId: list.id,
            lastMissedOn: lastMissedOn,
          );
          if (result is Err<void>) return Result.err(result.failure);
          changes.add(
            ReconcileChange(
              list: list.copyWith(lastMissedOn: lastMissedOn),
              missed: true,
              advanced: false,
            ),
          );
        case ReconcileAdvanceAndFlag(
            :final newScheduledFor,
            :final lastMissedOn,
          ):
          final result = await _repository.applyScheduleReconciliation(
            listId: list.id,
            scheduledFor: newScheduledFor,
            lastMissedOn: lastMissedOn,
          );
          if (result is Err<void>) return Result.err(result.failure);
          changes.add(
            ReconcileChange(
              list: list.copyWith(
                scheduledFor: newScheduledFor,
                lastMissedOn: lastMissedOn,
              ),
              missed: true,
              advanced: true,
            ),
          );
      }
    }
    return Result.ok(changes);
  }
}
