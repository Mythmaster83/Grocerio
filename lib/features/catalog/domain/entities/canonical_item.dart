import 'package:equatable/equatable.dart';
import 'item_category.dart';

/// A shared, canonical product identity ("Milk, whole gallon") that price
/// reports attach to. Free-text item names on a list resolve *to* one of these
/// so that two shoppers typing "milk" and "whole milk" contribute to the same
/// price record.
class CanonicalItem extends Equatable {
  /// Local Isar id. Not portable between devices — see [slug].
  final int id;

  /// Stable identity, identical on every install because it comes from the
  /// bundled seed data. This is what crosses the network during sync; local
  /// ids are translated at that boundary.
  final String slug;

  final String name;
  final ItemCategory category;
  final List<String> aliasKeywords;

  const CanonicalItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.category,
    required this.aliasKeywords,
  });

  @override
  List<Object?> get props => [id, slug, name, category, aliasKeywords];
}
