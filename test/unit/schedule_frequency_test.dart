import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

void main() {
  group('ScheduleFequency.nextOcurrence', () {

    test("returns null when occurrence is once", () {
      final result = ScheduleFrequency.oneTime.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, isNull);
    });

    test("carries into next month, biweekly", () {
      final result = ScheduleFrequency.biweekly.nextOccurrence(DateTime(2026, 6, 15));
      expect(result, DateTime(2026, 6, 29));
    });

    test("30th jan monthly does not carry into march", () {
      final result = ScheduleFrequency.monthly.nextOccurrence(DateTime(2026, 1, 30));
      expect(result, DateTime(2026, 2, 28));

      expect(result!.month, 2, reason:'buggy code expected to carry over to march 3nd');
    });

    test("30th jan monthly does not carry into march during leap year", () {
      final result = ScheduleFrequency.monthly.nextOccurrence(DateTime(2024, 1, 31));
      expect(result, DateTime(2024, 2, 29));

      expect(result!.month, 2, reason:'buggy code expected to carry over to march 3nd');
    });

  });
}