import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/lists/domain/entities/grocery_list.dart';
import 'package:grocer/features/lists/domain/list_sections.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

void main() {
  final now = DateTime(2026, 8, 17, 14);

  GroceryList listOn(DateTime date, {String name = 'List'}) => GroceryList(
        id: '$name-${date.toIso8601String()}',
        name: name,
        frequency: ScheduleFrequency.weekly,
        scheduledFor: date,
        createdAt: now,
        items: const [],
      );

  group('groupIntoSections', () {
    test('splits by overdue, within a week, and beyond', () {
      final sections = groupIntoSections(
        [
          listOn(DateTime(2026, 8, 15), name: 'Late'),
          listOn(DateTime(2026, 8, 19), name: 'Soon'),
          listOn(DateTime(2026, 9, 1), name: 'Distant'),
        ],
        now: now,
      );

      expect(
        sections.map((s) => s.section),
        [ListSection.overdue, ListSection.thisWeek, ListSection.later],
      );
      expect(sections[0].lists.single.name, 'Late');
      expect(sections[1].lists.single.name, 'Soon');
      expect(sections[2].lists.single.name, 'Distant');
    });

    test('today counts as this week, not overdue', () {
      // Scheduled earlier in the day than `now`: still today, not late.
      final sections = groupIntoSections([listOn(DateTime(2026, 8, 17, 8))], now: now);

      expect(sections.single.section, ListSection.thisWeek);
    });

    test('the seventh day out is still this week and the eighth is later', () {
      final sections = groupIntoSections(
        [
          listOn(DateTime(2026, 8, 24), name: 'Day 7'),
          listOn(DateTime(2026, 8, 25), name: 'Day 8'),
        ],
        now: now,
      );

      expect(sections[0].section, ListSection.thisWeek);
      expect(sections[0].lists.single.name, 'Day 7');
      expect(sections[1].section, ListSection.later);
    });

    test('empty sections are omitted entirely', () {
      final sections = groupIntoSections([listOn(DateTime(2026, 8, 18))], now: now);

      expect(sections, hasLength(1));
      expect(sections.single.section, ListSection.thisWeek);
    });

    test('no lists yields no sections', () {
      expect(groupIntoSections(const [], now: now), isEmpty);
    });
  });
}
