import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/lists/domain/entities/grocery_list.dart';
import 'package:grocer/features/lists/domain/schedule_rules.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

GroceryList _list({
  required ScheduleFrequency frequency,
  required DateTime scheduledFor,
  DateTime? lastMissedOn,
}) {
  return GroceryList(
    id: 'id',
    name: 'Test',
    frequency: frequency,
    scheduledFor: scheduledFor,
    createdAt: DateTime(2026, 1, 1),
    items: const [],
    lastMissedOn: lastMissedOn,
  );
}

void main() {
  group('planCompleteShopping', () {
    test('one-time deletes', () {
      final plan = planCompleteShopping(
        _list(
          frequency: ScheduleFrequency.oneTime,
          scheduledFor: DateTime(2026, 6, 15),
        ),
      );
      expect(plan, isA<DeleteListPlan>());
    });

    test('weekly advances from scheduledFor', () {
      final plan = planCompleteShopping(
        _list(
          frequency: ScheduleFrequency.weekly,
          scheduledFor: DateTime(2026, 6, 15),
        ),
      );
      expect(plan, isA<AdvanceListPlan>());
      expect(
        (plan as AdvanceListPlan).newScheduledFor,
        DateTime(2026, 6, 22),
      );
    });

    test('monthly advances with clamp', () {
      final plan = planCompleteShopping(
        _list(
          frequency: ScheduleFrequency.monthly,
          scheduledFor: DateTime(2026, 1, 31),
        ),
      );
      expect(
        (plan as AdvanceListPlan).newScheduledFor,
        DateTime(2026, 2, 28),
      );
    });
  });

  group('planReconciliation', () {
    test('future date is no-op', () {
      final plan = planReconciliation(
        _list(
          frequency: ScheduleFrequency.weekly,
          scheduledFor: DateTime(2026, 7, 20),
        ),
        DateTime(2026, 7, 15),
      );
      expect(plan, isA<ReconcileNoOp>());
    });

    test('same calendar day is no-op', () {
      final plan = planReconciliation(
        _list(
          frequency: ScheduleFrequency.weekly,
          scheduledFor: DateTime(2026, 7, 15, 8),
        ),
        DateTime(2026, 7, 15, 20),
      );
      expect(plan, isA<ReconcileNoOp>());
    });

    test('one-time overdue flags without changing date', () {
      final plan = planReconciliation(
        _list(
          frequency: ScheduleFrequency.oneTime,
          scheduledFor: DateTime(2026, 7, 10),
        ),
        DateTime(2026, 7, 15),
      );
      expect(plan, isA<ReconcileFlagOnly>());
      expect((plan as ReconcileFlagOnly).lastMissedOn, DateTime(2026, 7, 10));
    });

    test('weekly overdue advances one week and flags', () {
      final plan = planReconciliation(
        _list(
          frequency: ScheduleFrequency.weekly,
          scheduledFor: DateTime(2026, 7, 8),
        ),
        DateTime(2026, 7, 15),
      );
      expect(plan, isA<ReconcileAdvanceAndFlag>());
      final advance = plan as ReconcileAdvanceAndFlag;
      expect(advance.lastMissedOn, DateTime(2026, 7, 8));
      expect(advance.newScheduledFor, DateTime(2026, 7, 15));
    });

    test('weekly multi-period skip advances to future', () {
      // Scheduled Jun 1, today Jul 15 → should land on or after Jul 15
      final plan = planReconciliation(
        _list(
          frequency: ScheduleFrequency.weekly,
          scheduledFor: DateTime(2026, 6, 1),
        ),
        DateTime(2026, 7, 15),
      );
      expect(plan, isA<ReconcileAdvanceAndFlag>());
      final advance = plan as ReconcileAdvanceAndFlag;
      expect(advance.lastMissedOn, isNotNull);
      expect(
        calendarDate(advance.newScheduledFor)
            .isBefore(DateTime(2026, 7, 15)),
        isFalse,
      );
    });
  });
}
