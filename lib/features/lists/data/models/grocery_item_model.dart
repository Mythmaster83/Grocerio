import 'package:isar/isar.dart';
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

  late bool isChecked;
  String? imageUrl;
  late DateTime updatedAt;

  GroceryItem toDomain() => GroceryItem(
        id: id,
        name: name,
        quantity: quantity,
        unit: unit.toDomain(),
        isChecked: isChecked,
        imageUrl: imageUrl,
        updatedAt: updatedAt,
      );

  static GroceryItemModel fromDomain(GroceryItem item) => GroceryItemModel()
    ..id = item.id
    ..name = item.name
    ..quantity = item.quantity
    ..unit = ItemUnitDbX.fromDomain(item.unit)
    ..isChecked = item.isChecked
    ..imageUrl = item.imageUrl
    ..updatedAt = item.updatedAt;
}

/// Separate DB-facing enum from the domain enum on purpose: reordering the
/// domain enum's cases must never silently reindex Isar's @enumerated
/// storage. This indirection is boilerplate but it's the boilerplate that
/// prevents silent data corruption after a refactor.
enum ItemUnitDb { piece, kg, g, l, ml, pack, dozen }

extension ItemUnitDbX on ItemUnitDb {
  ItemUnit toDomain() => ItemUnit.values[index];
  static ItemUnitDb fromDomain(ItemUnit unit) => ItemUnitDb.values[unit.index];
}
