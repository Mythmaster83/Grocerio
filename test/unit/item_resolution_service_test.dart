import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/catalog/domain/entities/canonical_item.dart';
import 'package:grocer/features/catalog/domain/entities/item_category.dart';
import 'package:grocer/features/catalog/domain/services/item_resolution_service.dart';

/// Mirrors the shape of the seed asset: aliases are lowercase and include the
/// item's own name.
CanonicalItem _item(
  int id,
  String slug,
  String name,
  ItemCategory category,
  List<String> aliases,
) =>
    CanonicalItem(
      id: id,
      slug: slug,
      name: name,
      category: category,
      aliasKeywords: [name.toLowerCase(), ...aliases],
    );

void main() {
  const resolver = ItemResolutionService();

  final catalog = [
    _item(1, 'milk-whole', 'Whole milk', ItemCategory.dairy,
        ['milk', 'whole milk', 'vitamin d milk']),
    _item(2, 'almond-milk', 'Almond milk', ItemCategory.dairy,
        ['almond milk', 'almondmilk']),
    _item(3, 'bananas', 'Bananas', ItemCategory.produce,
        ['banana', 'bananas', 'bannanas']),
    _item(4, 'chicken-breast', 'Chicken breast', ItemCategory.meat,
        ['chicken', 'chicken breast']),
    _item(5, 'toilet-paper', 'Toilet paper', ItemCategory.household,
        ['toilet paper', 'tp']),
  ];

  group('normalizeItemName', () {
    test('lowercases, strips punctuation and collapses whitespace', () {
      expect(normalizeItemName('  Whole   MILK!! '), 'whole milk');
      expect(normalizeItemName('2% milk'), '2 milk');
      expect(normalizeItemName('---'), '');
    });
  });

  group('exact alias matching', () {
    test('matches an alias verbatim', () {
      expect(resolver.resolve('milk', catalog)?.slug, 'milk-whole');
      expect(resolver.resolve('tp', catalog)?.slug, 'toilet-paper');
    });

    test('is case and punctuation insensitive', () {
      expect(resolver.resolve('Whole Milk.', catalog)?.slug, 'milk-whole');
    });
  });

  group('contained alias matching', () {
    test('prefers the most specific alias', () {
      // Both "milk" and "almond milk" are contained; the longer one wins,
      // otherwise almond milk prices would be filed under dairy milk.
      expect(resolver.resolve('organic almond milk', catalog)?.slug,
          'almond-milk');
    });

    test('matches regardless of word order', () {
      expect(resolver.resolve('milk whole', catalog)?.slug, 'milk-whole');
    });

    test('falls back to the generic alias when no specific one applies', () {
      expect(resolver.resolve('milk for cereal', catalog)?.slug, 'milk-whole');
    });
  });

  group('fuzzy matching', () {
    test('tolerates a single-character typo', () {
      expect(resolver.resolve('chiken', catalog)?.slug, 'chicken-breast');
      expect(resolver.resolve('bannana', catalog)?.slug, 'bananas');
    });

    test('refuses fuzzy matching on very short input', () {
      // "tea" is one edit from "tp"'s neighbours; short strings are all
      // neighbours of each other, so no match is the correct answer.
      expect(resolver.resolve('cap', catalog), isNull);
    });
  });

  group('returns null rather than forcing a match', () {
    test('near-miss words that are not the same product', () {
      expect(resolver.resolve('milkshake', catalog), isNull);
      expect(resolver.resolve('bananagrams', catalog), isNull);
    });

    test('unrelated input', () {
      expect(resolver.resolve('lawn mower', catalog), isNull);
    });

    test('empty and whitespace input', () {
      expect(resolver.resolve('', catalog), isNull);
      expect(resolver.resolve('   ', catalog), isNull);
    });

    test('empty catalog', () {
      expect(resolver.resolve('milk', const []), isNull);
    });
  });
}
