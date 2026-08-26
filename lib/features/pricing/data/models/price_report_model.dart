import 'package:isar_community/isar.dart';
import '../../domain/entities/price_report.dart';

part 'price_report_model.g.dart';

@collection
class PriceReportModel {
  Id isarId = Isar.autoIncrement;

  /// UUID. Unique so a report arriving twice from sync replaces rather than
  /// duplicates itself.
  @Index(unique: true, replace: true)
  late String publicId;

  /// Composite index so "latest report per store for this item" is an index
  /// walk instead of a full scan; the ordering of the parts matches how the
  /// repository queries (item first, then store, then recency).
  @Index(composite: [CompositeIndex('storeId'), CompositeIndex('reportedAt')])
  late int canonicalItemId;

  late int storeId;
  late double price;
  late String unit;
  late DateTime reportedAt;

  /// Device id today, account id once Supabase auth lands.
  late String reportedBy;

  String? zip;

  /// Tombstone. Reports are soft-deleted so a suppression can propagate
  /// through sync; a hard delete would simply reappear from another device.
  DateTime? deletedAt;

  PriceReport toDomain() => PriceReport(
        id: publicId,
        canonicalItemId: canonicalItemId,
        storeId: storeId,
        price: price,
        unit: unit,
        reportedAt: reportedAt,
        reportedBy: reportedBy,
        zip: zip,
      );
}
