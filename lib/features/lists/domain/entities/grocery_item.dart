import 'package:equatable/equatable.dart';

/// Units of measurement. **Append only** — the index is what Isar persists
/// (`@enumerated`), so reordering or inserting silently rewrites stored data.
///
/// [custom] means "the label is free text the user typed"; it lives in
/// `GroceryItem.customUnit` rather than as its own enum case per unit.
enum ItemUnit {
  piece,
  kg,
  g,
  l,
  ml,
  pack,
  dozen,
  gallon,
  carton,
  can,
  custom,
}

/// Units offered directly in the picker. [ItemUnit.custom] is deliberately
/// excluded: it is reached by typing a label, never by selecting "custom".
List<ItemUnit> get builtInUnits =>
    ItemUnit.values.where((u) => u != ItemUnit.custom).toList();

/// Display label for a unit + its optional custom text.
String itemUnitLabel(ItemUnit unit, String? customUnit) =>
    unit == ItemUnit.custom ? (customUnit?.trim() ?? '') : unit.name;

/// Inverse of [itemUnitLabel]: turns a picker label back into something
/// persistable. A label that matches a built-in unit name wins; anything else
/// is treated as a custom label.
({ItemUnit unit, String? customUnit}) itemUnitFromLabel(String label) {
  final trimmed = label.trim();
  for (final unit in builtInUnits) {
    if (unit.name == trimmed) return (unit: unit, customUnit: null);
  }
  return (unit: ItemUnit.custom, customUnit: trimmed);
}

/// Domain entity — plain Dart, zero Isar/Riverpod/Flutter imports.
/// This is what the UI and usecases talk about. It is deliberately
/// decoupled from GroceryItemModel (the persistence shape) so that
/// swapping storage engines later never touches domain or presentation.
///
/// No image fields: the item's icon is derived from [name] at render time
/// (see features/item_icons), so there is nothing image-related to persist.
class GroceryItem extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final ItemUnit unit;

  /// Free-text unit label, set only when [unit] is [ItemUnit.custom].
  final String? customUnit;

  /// Catalog identity this item resolved to, or null when the name matched
  /// nothing. Null means "no shared price identity", which is why the UI shows
  /// no price rather than an error.
  final int? canonicalItemId;

  final bool isChecked;
  final DateTime updatedAt;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.updatedAt,
    this.customUnit,
    this.canonicalItemId,
  });

  /// What the UI and the shared text export should print.
  String get unitLabel => itemUnitLabel(unit, customUnit);

  GroceryItem copyWith({
    String? name,
    double? quantity,
    ItemUnit? unit,
    String? customUnit,
    int? canonicalItemId,
    bool? isChecked,
    DateTime? updatedAt,
  }) {
    return GroceryItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      customUnit: customUnit ?? this.customUnit,
      canonicalItemId: canonicalItemId ?? this.canonicalItemId,
      isChecked: isChecked ?? this.isChecked,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        quantity,
        unit,
        customUnit,
        canonicalItemId,
        isChecked,
        updatedAt,
      ];
}
