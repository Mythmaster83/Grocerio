import 'entities/grocery_list.dart';

enum ListSection { overdue, thisWeek, later }

extension ListSectionX on ListSection {
  String get label => switch (this) {
        ListSection.overdue => 'Overdue',
        ListSection.thisWeek => 'This week',
        ListSection.later => 'Later',
      };
}

class ListSectionGroup {
  final ListSection section;
  final List<GroceryList> lists;

  const ListSectionGroup(this.section, this.lists);
}

/// Splits lists into the three buckets home renders.
///
/// Pure and calendar-day based: comparing whole days rather than 168-hour
/// windows is what keeps a trip planned for Sunday evening from falling into
/// "Later" just because it's now Sunday morning plus seven days.
List<ListSectionGroup> groupIntoSections(
  List<GroceryList> lists, {
  DateTime? now,
}) {
  final today = _dayOf(now ?? DateTime.now());

  final overdue = <GroceryList>[];
  final thisWeek = <GroceryList>[];
  final later = <GroceryList>[];

  for (final list in lists) {
    final days = _dayOf(list.scheduledFor).difference(today).inDays;
    if (days < 0) {
      overdue.add(list);
    } else if (days <= 7) {
      thisWeek.add(list);
    } else {
      later.add(list);
    }
  }

  return [
    if (overdue.isNotEmpty) ListSectionGroup(ListSection.overdue, overdue),
    if (thisWeek.isNotEmpty) ListSectionGroup(ListSection.thisWeek, thisWeek),
    if (later.isNotEmpty) ListSectionGroup(ListSection.later, later),
  ];
}

/// UTC midnight so a daylight-saving shift can't make a day 23 hours long and
/// change which bucket a list lands in.
DateTime _dayOf(DateTime date) => DateTime.utc(date.year, date.month, date.day);
