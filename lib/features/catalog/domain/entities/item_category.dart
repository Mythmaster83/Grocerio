/// Fixed category list. Deliberately a closed enum rather than freeform text:
/// it drives the icon fallback for unmatched items and the Price Lookup filter
/// chips, and both break if categories can be invented per item.
///
/// **Append only** — the index is what Isar persists via `ItemCategoryDb`.
enum ItemCategory {
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

extension ItemCategoryX on ItemCategory {
  String get label => switch (this) {
        ItemCategory.produce => 'Produce',
        ItemCategory.dairy => 'Dairy',
        ItemCategory.meat => 'Meat',
        ItemCategory.pantry => 'Pantry',
        ItemCategory.frozen => 'Frozen',
        ItemCategory.bakery => 'Bakery',
        ItemCategory.beverages => 'Beverages',
        ItemCategory.household => 'Household',
        ItemCategory.other => 'Other',
      };

  /// Parses the value stored in the seed JSON. Unknown strings fall back to
  /// [ItemCategory.other] rather than throwing: a typo in seed data should not
  /// take the whole catalog load down.
  static ItemCategory fromName(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final category in ItemCategory.values) {
      if (category.name == normalized) return category;
    }
    return ItemCategory.other;
  }
}
