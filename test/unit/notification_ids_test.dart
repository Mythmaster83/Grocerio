import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/notifications/domain/notification_ids.dart';

void main() {
  group('notificationIdForList', () {
    test('is stable for the same id', () {
      final a = notificationIdForList('abc-123');
      final b = notificationIdForList('abc-123');
      expect(a, b);
    });

    test('differs for different ids', () {
      expect(
        notificationIdForList('list-a'),
        isNot(notificationIdForList('list-b')),
      );
    });

    test('stays in positive 31-bit range', () {
      final id = notificationIdForList('a-long-uuid-value-here');
      expect(id, greaterThan(0));
      expect(id, lessThanOrEqualTo(0x7fffffff));
    });
  });

  group('shoppingDayReminderLocal', () {
    test('is 09:00 on the calendar date', () {
      final result = shoppingDayReminderLocal(DateTime(2026, 7, 15, 22, 30));
      expect(result, DateTime(2026, 7, 15, 9));
    });
  });
}
