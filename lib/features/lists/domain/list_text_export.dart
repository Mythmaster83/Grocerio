import 'entities/grocery_item.dart';
import 'entities/grocery_list.dart';

/// Renders a list as plain text for sharing (clipboard / messaging apps):
///
/// ```
/// Weekly groceries — 4th Aug 2026
///
/// 1 carton milk
/// 1 dozen eggs
/// 4 bananas
/// ```
///
/// Pure function so the exact wording is unit-testable without a widget tree.
/// `piece` is omitted as a unit because "4 piece bananas" reads worse than
/// "4 bananas" to whoever receives the message.
String formatListForSharing(GroceryList list) {
  final header = '${list.name} — ${formatShareDate(list.scheduledFor)}';
  if (list.items.isEmpty) return '$header\n\n(no items yet)';

  final lines = list.items.map(_formatItem).join('\n');
  return '$header\n\n$lines';
}

String _formatItem(GroceryItem item) {
  final quantity = formatShareQuantity(item.quantity);
  final unit = item.unit == ItemUnit.piece ? '' : item.unitLabel.trim();
  return unit.isEmpty ? '$quantity ${item.name}' : '$quantity $unit ${item.name}';
}

/// "4th Aug 2026" — day-with-ordinal is friendlier in a message than the
/// locale-numeric formats `intl` offers out of the box.
String formatShareDate(DateTime date) =>
    '${date.day}${_ordinalSuffix(date.day)} ${_monthNames[date.month - 1]} ${date.year}';

String formatShareQuantity(double quantity) =>
    quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th'; // 11th, 12th, 13th — not 11st
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
