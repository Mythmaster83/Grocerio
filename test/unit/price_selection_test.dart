import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/pricing/domain/entities/price_report.dart';
import 'package:grocer/features/pricing/domain/price_selection.dart';
import 'package:grocer/features/stores/domain/entities/store.dart';

void main() {
  final now = DateTime(2026, 8, 17, 12);

  const kroger = Store(
    id: 1,
    slug: 'kroger',
    name: 'Kroger',
    chainSlug: 'kroger',
    trackedByUser: true,
  );
  const walmart = Store(
    id: 2,
    slug: 'walmart',
    name: 'Walmart',
    chainSlug: 'walmart',
    trackedByUser: true,
  );
  const publix = Store(
    id: 3,
    slug: 'publix',
    name: 'Publix',
    chainSlug: 'publix',
    trackedByUser: false,
  );
  final stores = [kroger, walmart, publix];

  PriceReport report({
    required String id,
    int itemId = 10,
    required int storeId,
    required double price,
    required Duration age,
    String unit = 'gallon',
  }) =>
      PriceReport(
        id: id,
        canonicalItemId: itemId,
        storeId: storeId,
        price: price,
        unit: unit,
        reportedAt: now.subtract(age),
        reportedBy: 'device-1',
      );

  group('grouping', () {
    test('keeps only the newest report per store', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'a', storeId: 1, price: 4.99, age: const Duration(days: 3)),
          report(id: 'b', storeId: 1, price: 3.49, age: const Duration(hours: 2)),
        ],
        stores: stores,
        now: now,
      );

      expect(comparison.byStore, hasLength(1));
      expect(comparison.cheapest?.reportId, 'b');
      expect(comparison.cheapest?.price, 3.49);
    });

    test('sorts ascending by price so cheapest is first', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'a', storeId: 1, price: 4.29, age: const Duration(hours: 1)),
          report(id: 'b', storeId: 2, price: 3.79, age: const Duration(hours: 1)),
          report(id: 'c', storeId: 3, price: 5.10, age: const Duration(hours: 1)),
        ],
        stores: stores,
        now: now,
      );

      expect(comparison.byStore.map((p) => p.storeName),
          ['Walmart', 'Kroger', 'Publix']);
      expect(comparison.cheapest?.storeName, 'Walmart');
    });

    test('keeps brand and city/state on separate fields', () {
      const krogerGa = Store(
        id: 1,
        slug: 'kroger',
        name: 'Kroger',
        chainSlug: 'kroger',
        trackedByUser: true,
        city: 'Stone Mountain',
        state: 'GA',
      );
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'a', storeId: 1, price: 3.49, age: const Duration(minutes: 4)),
        ],
        stores: [krogerGa],
        now: now,
      );

      expect(comparison.cheapest?.storeName, 'Kroger');
      expect(comparison.cheapest?.storePlace, 'Stone Mountain, GA');
      expect(comparison.cheapest?.storeName.contains('Stone'), isFalse);
    });

    test('ignores reports for other items', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'a', itemId: 99, storeId: 1, price: 1.00, age: Duration.zero),
        ],
        stores: stores,
        now: now,
      );

      expect(comparison.hasAnyPrice, isFalse);
      expect(comparison.cheapest, isNull);
    });

    test('drops reports whose store no longer exists', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [report(id: 'a', storeId: 404, price: 1.00, age: Duration.zero)],
        stores: stores,
        now: now,
      );

      expect(comparison.byStore, isEmpty);
    });

    test('applies the store filter', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'a', storeId: 1, price: 4.29, age: const Duration(hours: 1)),
          report(id: 'b', storeId: 2, price: 3.79, age: const Duration(hours: 1)),
        ],
        stores: stores,
        now: now,
        storeIdsFilter: {1},
      );

      expect(comparison.byStore.map((p) => p.storeName), ['Kroger']);
    });
  });

  group('freshness and TTL', () {
    test('reports inside the fresh window are not stale', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [report(id: 'a', storeId: 1, price: 3.00, age: const Duration(days: 6))],
        stores: stores,
        now: now,
      );

      expect(comparison.cheapest?.isStale, isFalse);
    });

    test('reports past the fresh window are shown but flagged stale', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [report(id: 'a', storeId: 1, price: 3.00, age: const Duration(days: 9))],
        stores: stores,
        now: now,
      );

      expect(comparison.byStore, hasLength(1));
      expect(comparison.cheapest?.isStale, isTrue);
    });

    test('reports past the hard age limit are excluded entirely', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [report(id: 'a', storeId: 1, price: 3.00, age: const Duration(days: 31))],
        stores: stores,
        now: now,
      );

      expect(comparison.hasAnyPrice, isFalse);
    });

    test('a stale cheap price still beats a fresh expensive one', () {
      // Deliberate: hiding the cheaper number would be worse than showing it
      // with a visible "3w ago" caveat.
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'old', storeId: 1, price: 2.99, age: const Duration(days: 20)),
          report(id: 'new', storeId: 2, price: 4.99, age: const Duration(hours: 1)),
        ],
        stores: stores,
        now: now,
      );

      expect(comparison.cheapest?.reportId, 'old');
      expect(comparison.cheapest?.isStale, isTrue);
    });

    test('equal prices prefer the fresher report', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [
          report(id: 'old', storeId: 1, price: 3.50, age: const Duration(days: 5)),
          report(id: 'new', storeId: 2, price: 3.50, age: const Duration(hours: 1)),
        ],
        stores: stores,
        now: now,
      );

      expect(comparison.cheapest?.reportId, 'new');
    });

    test('windows are overridable so the constants can be tuned', () {
      final comparison = buildPriceComparison(
        canonicalItemId: 10,
        reports: [report(id: 'a', storeId: 1, price: 3.00, age: const Duration(days: 2))],
        stores: stores,
        now: now,
        freshWindow: const Duration(days: 1),
      );

      expect(comparison.cheapest?.isStale, isTrue);
    });
  });

  group('formatReportedAge', () {
    test('renders compact relative ages', () {
      expect(formatReportedAge(now, now), 'just now');
      expect(formatReportedAge(now.subtract(const Duration(minutes: 5)), now), '5m ago');
      expect(formatReportedAge(now.subtract(const Duration(hours: 3)), now), '3h ago');
      expect(formatReportedAge(now.subtract(const Duration(days: 2)), now), '2d ago');
      expect(formatReportedAge(now.subtract(const Duration(days: 15)), now), '2w ago');
    });
  });
}
