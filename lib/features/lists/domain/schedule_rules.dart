import '../../scheduling/domain/entities/schedule_frequency.dart';
import 'entities/grocery_list.dart';

/// Calendar date only (time stripped) for overdue comparisons.
DateTime calendarDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pure plan for Completing Shopping — no I/O.
sealed class CompleteShoppingPlan {
  const CompleteShoppingPlan();
}

class DeleteListPlan extends CompleteShoppingPlan {
  const DeleteListPlan();
}

class AdvanceListPlan extends CompleteShoppingPlan {
  final DateTime newScheduledFor;
  const AdvanceListPlan(this.newScheduledFor);
}

CompleteShoppingPlan planCompleteShopping(GroceryList list) {
  if (list.frequency == ScheduleFrequency.oneTime) {
    return const DeleteListPlan();
  }
  final next = list.frequency.nextOccurrence(list.scheduledFor);
  if (next == null) {
    // Recurring frequencies always return a date; treat as delete if not.
    return const DeleteListPlan();
  }
  return AdvanceListPlan(next);
}

/// Pure plan for startup reconciliation of one list.
sealed class ReconcilePlan {
  const ReconcilePlan();
}

class ReconcileNoOp extends ReconcilePlan {
  const ReconcileNoOp();
}

class ReconcileFlagOnly extends ReconcilePlan {
  final DateTime lastMissedOn;
  const ReconcileFlagOnly(this.lastMissedOn);
}

class ReconcileAdvanceAndFlag extends ReconcilePlan {
  final DateTime newScheduledFor;
  final DateTime lastMissedOn;
  const ReconcileAdvanceAndFlag({
    required this.newScheduledFor,
    required this.lastMissedOn,
  });
}

/// Returns what reconciliation should do for [list] given [now] (any time of day).
ReconcilePlan planReconciliation(GroceryList list, DateTime now) {
  final today = calendarDate(now);
  final scheduled = calendarDate(list.scheduledFor);
  if (!today.isAfter(scheduled)) {
    return const ReconcileNoOp();
  }

  if (list.frequency == ScheduleFrequency.oneTime) {
    return ReconcileFlagOnly(scheduled);
  }

  var current = list.scheduledFor;
  late DateTime lastMissed;
  while (today.isAfter(calendarDate(current))) {
    lastMissed = calendarDate(current);
    final next = list.frequency.nextOccurrence(current);
    if (next == null) {
      return ReconcileFlagOnly(lastMissed);
    }
    current = next;
  }
  return ReconcileAdvanceAndFlag(
    newScheduledFor: current,
    lastMissedOn: lastMissed,
  );
}
