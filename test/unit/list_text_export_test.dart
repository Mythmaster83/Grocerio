import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/lists/domain/entities/grocery_item.dart';
import 'package:grocer/features/lists/domain/entities/grocery_list.dart';
import 'package:grocer/features/lists/domain/list_text_export.dart';
import 'package:grocer/features/scheduling/domain/entities/schedule_frequency.dart';

GroceryItem _item(
  String name,
  double quantity,
  ItemUnit unit, {
  String? customUnit,
}) =>
    GroceryItem(
      id: name,
      name: name,
      quantity: quantity,
      unit: unit,
      customUnit: customUnit,
      isChecked: false,
      updatedAt: DateTime(2026, 8, 4),
    );

GroceryList _list(List<GroceryItem> items) => GroceryList(
      id: 'list-1',
      name: 'Weekly groceries',
      frequency: ScheduleFrequency.weekly,
      scheduledFor: DateTime(2026, 8, 4),
      createdAt: DateTime(2026, 8, 1),
      items: items,
    );

void main() {
  group('formatListForSharing', () {
    test('renders title, ordinal date, then one line per item', () {
      final text = formatListForSharing(_list([
        _item('milk', 1, ItemUnit.carton),
        _item('eggs', 1, ItemUnit.dozen),
        _item('bananas', 4, ItemUnit.piece),
      ]));

      expect(
        text,
        'Weekly groceries — 4th Aug 2026\n'
        '\n'
        '1 carton milk\n'
        '1 dozen eggs\n'
        '4 bananas',
      );
    });

    test('uses the custom label for custom units', () {
      final text = formatListForSharing(_list([
        _item('coriander', 2, ItemUnit.custom, customUnit: 'bunch'),
      ]));

      expect(text, endsWith('2 bunch coriander'));
    });

    test('keeps fractional quantities and notes an empty list', () {
      expect(
        formatListForSharing(_list([_item('mince', 1.5, ItemUnit.kg)])),
        endsWith('1.5 kg mince'),
      );
      expect(formatListForSharing(_list([])), endsWith('(no items yet)'));
    });
  });

  group('formatShareDate', () {
    test('picks the right ordinal suffix, including the teens', () {
      expect(formatShareDate(DateTime(2026, 8, 1)), '1st Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 2)), '2nd Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 3)), '3rd Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 11)), '11th Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 12)), '12th Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 13)), '13th Aug 2026');
      expect(formatShareDate(DateTime(2026, 8, 21)), '21st Aug 2026');
    });
  });
}
