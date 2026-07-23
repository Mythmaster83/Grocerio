import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

void main() {
  group('ScheduleFrequency.nextOccurrence', () {
    test('oneTime returns null', () {
      final result =
          ScheduleFrequency.oneTime.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, isNull);
    });

    test('weekly adds 7 days', () {
      final result =
          ScheduleFrequency.weekly.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, DateTime(2026, 6, 22));
    });

    test('biweekly adds 14 days and can cross months', () {
      final result =
          ScheduleFrequency.biweekly.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, DateTime(2026, 6, 29));
    });

    test('monthly Jan 30 non-leap clamps to Feb 28', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 1, 30));
      expect(result, DateTime(2026, 2, 28));
      expect(result!.month, 2);
    });

    test('monthly Jan 31 leap year clamps to Feb 29', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2024, 1, 31));
      expect(result, DateTime(2024, 2, 29));
      expect(result!.month, 2);
    });

    test('monthly Mar 31 clamps to Apr 30', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 3, 31));
      expect(result, DateTime(2026, 4, 30));
    });

    test('monthly May 31 clamps to Jun 30', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 5, 31));
      expect(result, DateTime(2026, 6, 30));
    });

    test('monthly Aug 31 clamps to Sep 30', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 8, 31));
      expect(result, DateTime(2026, 9, 30));
    });

    test('monthly Dec 31 rolls to next year Jan 31', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 12, 31));
      expect(result, DateTime(2027, 1, 31));
    });

    test('monthly mid-month preserves day', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, DateTime(2026, 7, 15));
    });

    test('monthly Feb 28 non-leap goes to Mar 28', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 2, 28));
      expect(result, DateTime(2026, 3, 28));
    });

    test('monthly Feb 29 leap goes to Mar 29', () {
      final result =
          ScheduleFrequency.monthly.nextOccurrence(DateTime(2024, 2, 29));
      expect(result, DateTime(2024, 3, 29));
    });
  });
}
