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
  /// to unit test and reused by schedule reconciliation / Complete Shopping.
  ///
  /// Monthly advances by calendar month and **clamps** the day to the last
  /// valid day of the target month (e.g. Jan 31 → Feb 28/29, Mar 31 → Apr 30).
  /// Without clamping, Dart's `DateTime(y, m, d)` overflows into the next month.
  DateTime? nextOccurrence(DateTime from) {
    switch (this) {
      case ScheduleFrequency.oneTime:
        return null;
      case ScheduleFrequency.weekly:
        return from.add(const Duration(days: 7));
      case ScheduleFrequency.biweekly:
        return from.add(const Duration(days: 14));
      case ScheduleFrequency.monthly:
        return _addCalendarMonths(from, 1);
    }
  }
}

/// Adds [months] calendar months to [from], clamping the day to the last day
/// of the resulting month when needed.
DateTime _addCalendarMonths(DateTime from, int months) {
  final totalMonths = from.year * 12 + (from.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = (totalMonths % 12) + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = from.day > lastDay ? lastDay : from.day;
  return DateTime(year, month, day);
}
