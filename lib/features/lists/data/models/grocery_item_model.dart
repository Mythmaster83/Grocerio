import 'package:isar_community/isar.dart';
import '../../domain/entities/grocery_item.dart';

part 'grocery_item_model.g.dart';

/// Embedded Isar object (no @collection — it lives inside GroceryListModel.items).
/// Embedding, not a separate collection + IsarLink, is the right call here:
/// items have no independent lifecycle outside their list, and embedding
/// keeps "add item -> stream updates to UI" a single-document write, which
/// is both simpler and avoids the multi-collection sync bugs the previous
/// iteration likely hit with checkbox state.
@embedded
class GroceryItemModel {
  late String id;
  late String name;
  late double quantity;

  @enumerated
  late ItemUnitDb unit;

  /// Only set when [unit] is [ItemUnitDb.custom].
  String? customUnit;

  /// Resolved `CanonicalItemModel.isarId`, or null when the typed name matched
  /// nothing in the catalog. Null is a normal state, not an error: the item
  /// simply has no shared price identity and shows no price.
  ///
  /// This is a *local* id. Sync translates it via the canonical item's slug.
  int? canonicalItemId;

  late bool isChecked;
  late DateTime updatedAt;

  /// Tombstone for sync; see [GroceryListModel.deletedAt].
  DateTime? deletedAt;

  GroceryItem toDomain() => GroceryItem(
        id: id,
        name: name,
        quantity: quantity,
        unit: unit.toDomain(),
        customUnit: customUnit,
        canonicalItemId: canonicalItemId,
        isChecked: isChecked,
        updatedAt: updatedAt,
      );

  static GroceryItemModel fromDomain(GroceryItem item) => GroceryItemModel()
    ..id = item.id
    ..name = item.name
    ..quantity = item.quantity
    ..unit = ItemUnitDbX.fromDomain(item.unit)
    ..customUnit = item.customUnit
    ..canonicalItemId = item.canonicalItemId
    ..isChecked = item.isChecked
    ..updatedAt = item.updatedAt;
}

/// Separate DB-facing enum from the domain enum on purpose: reordering the
/// domain enum's cases must never silently reindex Isar's @enumerated
/// storage. This indirection is boilerplate but it's the boilerplate that
/// prevents silent data corruption after a refactor.
///
/// Must stay index-aligned with [ItemUnit] — append new units to **both**.
enum ItemUnitDb {
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

extension ItemUnitDbX on ItemUnitDb {
  ItemUnit toDomain() => ItemUnit.values[index];
  static ItemUnitDb fromDomain(ItemUnit unit) => ItemUnitDb.values[unit.index];
}
