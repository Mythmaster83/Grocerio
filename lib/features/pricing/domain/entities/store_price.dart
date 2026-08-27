import 'package:equatable/equatable.dart';

/// The best current price for one store: what a comparison cell renders.
class StorePrice extends Equatable {
  final int storeId;

  /// Chain / brand only ("Kroger"). Location lives in [storePlace] so the
  /// list-row trailing cell can put them on separate lines.
  final String storeName;

  /// City and state ("Stone Mountain, GA"), or empty when unknown.
  final String storePlace;

  final double price;

  /// The unit the reporter priced. Displayed verbatim, because a "$3.49" with
  /// no unit is what makes people distrust the whole feature.
  final String unit;

  final DateTime reportedAt;

  /// Older than the freshness window but still inside the hard age limit.
  /// Rendered greyed rather than hidden — an old price is information, a
  /// missing price is not.
  final bool isStale;

  /// Id of the underlying report, so the UI can attribute or suppress it.
  final String reportId;

  const StorePrice({
    required this.storeId,
    required this.storeName,
    this.storePlace = '',
    required this.price,
    required this.unit,
    required this.reportedAt,
    required this.isStale,
    required this.reportId,
  });

  @override
  List<Object?> get props => [
        storeId,
        storeName,
        storePlace,
        price,
        unit,
        reportedAt,
        isStale,
        reportId,
      ];
}

/// All stores' prices for one canonical item, cheapest first.
class PriceComparison extends Equatable {
  final int canonicalItemId;

  /// Sorted ascending by price. At most one entry per store.
  final List<StorePrice> byStore;

  const PriceComparison({
    required this.canonicalItemId,
    required this.byStore,
  });

  const PriceComparison.empty(this.canonicalItemId) : byStore = const [];

  /// Lowest price on offer, or null when nobody has reported this item.
  ///
  /// Caveat worth knowing: prices are only comparable when their units match,
  /// and nothing enforces that shoppers used the same one. The report sheet
  /// pre-fills the item's unit to keep them aligned in practice, and every cell
  /// shows its unit so a mismatch is visible rather than hidden.
  StorePrice? get cheapest => byStore.isEmpty ? null : byStore.first;

  bool get hasAnyPrice => byStore.isNotEmpty;

  @override
  List<Object?> get props => [canonicalItemId, byStore];
}
