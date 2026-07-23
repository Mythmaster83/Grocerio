/// How often a list recurs. Lives in its own tiny feature module because
/// both `lists` and (future) `notifications` need it — avoids a circular
/// dependency between those two features.
enum ScheduleFrequency { oneTime, weekly, biweekly, monthly }

extension ScheduleFrequencyX on ScheduleFrequency {
  String get label => switch (this) {
        ScheduleFrequency.oneTime => 'One-time',
        ScheduleFrequency.weekly => 'Weekly',
        ScheduleFrequency.biweekly => 'Biweekly',
        ScheduleFrequency.monthly => 'Monthly',
      };

  /// Computes the next occurrence from [from]. Pure function, no I/O — easy
  /// to unit test and reused by the (future) notifications scheduler.
  DateTime? nextOccurrence(DateTime from) {
    switch (this) {
      case ScheduleFrequency.oneTime:
        return null;
      case ScheduleFrequency.weekly:
        return from.add(const Duration(days: 7));
      case ScheduleFrequency.biweekly:
        return from.add(const Duration(days: 14));
      case ScheduleFrequency.monthly:
        if (from.month == 1 && from.day > 28) {
          if (from.year % 4 == 0) {
            return DateTime(from.year, 2, 29);
          } else {
            return DateTime(from.year, 2, 28);
          }
        } else {
          return DateTime(from.year, from.month+1, from.day);
        }
    }
  }
}
