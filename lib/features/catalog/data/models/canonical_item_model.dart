import 'package:isar_community/isar.dart';
import '../../domain/entities/canonical_item.dart';
import '../../domain/entities/item_category.dart';

part 'canonical_item_model.g.dart';

@collection
class CanonicalItemModel {
  Id isarId = Isar.autoIncrement;

  /// Seed-provided stable key ("milk-whole-gallon"). Unique so re-running the
  /// seeder updates rows instead of duplicating the catalog.
  @Index(unique: true, replace: true)
  late String slug;

  late String name;

  /// Lowercased [name], indexed so prefix search doesn't scan every row.
  @Index(caseSensitive: false)
  late String nameLower;

  @enumerated
  late ItemCategoryDb category;

  /// Lowercased match terms, including the name itself.
  List<String> aliasKeywords = const [];

  CanonicalItem toDomain() => CanonicalItem(
        id: isarId,
        slug: slug,
        name: name,
        category: category.toDomain(),
        aliasKeywords: List<String>.unmodifiable(aliasKeywords),
      );
}

/// DB-facing mirror of [ItemCategory]; must stay index-aligned with it.
enum ItemCategoryDb {
  produce,
  dairy,
  meat,
  pantry,
  frozen,
  bakery,
  beverages,
  household,
  other,
}

extension ItemCategoryDbX on ItemCategoryDb {
  ItemCategory toDomain() => ItemCategory.values[index];
  static ItemCategoryDb fromDomain(ItemCategory c) =>
      ItemCategoryDb.values[c.index];
}
