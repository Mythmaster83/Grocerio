import 'package:equatable/equatable.dart';

/// One shopper's observation of one price, at one store, at one moment.
///
/// Reports are append-only history rather than a mutable "current price" row:
/// the newest report per store wins at read time (see `PriceRepository`), which
/// is what makes staleness expressible instead of silently overwritten.
class PriceReport extends Equatable {
  /// UUID, stable across devices, so a synced report can be de-duplicated.
  final String id;

  final int canonicalItemId;
  final int storeId;
  final double price;

  /// Unit the price is *for* ("gallon", "dozen"), which need not match the
  /// quantity unit on anyone's list.
  final String unit;

  final DateTime reportedAt;

  /// Local device id before accounts exist, then the account's user id.
  /// Kept so a bad report can be attributed and later suppressed.
  final String reportedBy;

  /// Coarse location. Without a retailer location id, this is the only thing
  /// that keeps another region's prices out of a shopper's comparison.
  final String? zip;

  const PriceReport({
    required this.id,
    required this.canonicalItemId,
    required this.storeId,
    required this.price,
    required this.unit,
    required this.reportedAt,
    required this.reportedBy,
    this.zip,
  });

  @override
  List<Object?> get props =>
      [id, canonicalItemId, storeId, price, unit, reportedAt, reportedBy, zip];
}
