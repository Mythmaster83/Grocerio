import '../../stores/domain/entities/store.dart';
import 'entities/price_report.dart';
import 'entities/store_price.dart';

/// Reports newer than this are shown normally; older ones are marked
/// [StorePrice.isStale] and greyed.
///
/// This is the main tuning lever on whether prices feel trustworthy, which is
/// why it's a named constant rather than a literal buried in a query: with
/// shopper-reported data as the only source, too long a window shows wrong
/// prices and too short a one shows none at all.
const kPriceFreshWindow = Duration(days: 7);

/// Reports older than this are excluded entirely. Separate from the freshness
/// window on purpose: staleness is a display decision, exclusion is a data
/// decision, and collapsing them into one number means you can't grey a price
/// without also hiding it.
const kPriceMaxAge = Duration(days: 30);

/// Collapses raw report history into one price per store.
///
/// Pure so that grouping, the TTL cutoff, and the staleness flag are testable
/// without an Isar instance; [PriceRepository] just feeds it query results.
PriceComparison buildPriceComparison({
  required int canonicalItemId,
  required List<PriceReport> reports,
  required List<Store> stores,
  required DateTime now,
  Set<int>? storeIdsFilter,
  Duration freshWindow = kPriceFreshWindow,
  Duration maxAge = kPriceMaxAge,
}) {
  final storeById = {for (final store in stores) store.id: store};
  final freshCutoff = now.subtract(freshWindow);
  final ageCutoff = now.subtract(maxAge);

  // Newest report per store wins; ties broken by the later timestamp only, so
  // resubmitting the same price is a no-op rather than a flip-flop.
  final newestPerStore = <int, PriceReport>{};
  for (final report in reports) {
    if (report.canonicalItemId != canonicalItemId) continue;
    if (report.reportedAt.isBefore(ageCutoff)) continue;
    if (storeIdsFilter != null && !storeIdsFilter.contains(report.storeId)) {
      continue;
    }
    // A store that was deleted or never seeded has no name to render.
    if (!storeById.containsKey(report.storeId)) continue;

    final incumbent = newestPerStore[report.storeId];
    if (incumbent == null || report.reportedAt.isAfter(incumbent.reportedAt)) {
      newestPerStore[report.storeId] = report;
    }
  }

  final prices = [
    for (final report in newestPerStore.values)
      StorePrice(
        storeId: report.storeId,
        storeName: storeById[report.storeId]!.name,
        storePlace: storeById[report.storeId]!.cityState,
        price: report.price,
        unit: report.unit,
        reportedAt: report.reportedAt,
        isStale: report.reportedAt.isBefore(freshCutoff),
        reportId: report.id,
      ),
  ]..sort((a, b) {
      final byPrice = a.price.compareTo(b.price);
      // Equal prices: prefer the fresher report, so the cheapest cell isn't
      // arbitrarily the older of two identical quotes.
      return byPrice != 0 ? byPrice : b.reportedAt.compareTo(a.reportedAt);
    });

  return PriceComparison(canonicalItemId: canonicalItemId, byStore: prices);
}

/// "2h ago", "3d ago". Short by necessity: this sits under a price inside a
/// list row, where anything longer wraps.
String formatReportedAge(DateTime reportedAt, DateTime now) {
  final elapsed = now.difference(reportedAt);
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  final weeks = elapsed.inDays ~/ 7;
  return '${weeks}w ago';
}
