DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value.toString())?.toLocal();
}

/// Wire format for `price_reports`. Slugs, not local integer ids — catalog and
/// store ids differ per install, slugs do not.
class RemotePriceReport {
  final String id;
  final String canonicalSlug;
  final String storeSlug;
  final double price;
  final String unit;
  final DateTime reportedAt;
  final String reportedBy;
  final String? zip;

  const RemotePriceReport({
    required this.id,
    required this.canonicalSlug,
    required this.storeSlug,
    required this.price,
    required this.unit,
    required this.reportedAt,
    required this.reportedBy,
    required this.zip,
  });

  factory RemotePriceReport.fromJson(Map<String, dynamic> json) {
    return RemotePriceReport(
      id: json['id'] as String,
      canonicalSlug: json['canonical_slug'] as String,
      storeSlug: json['store_slug'] as String,
      price: (json['price'] as num).toDouble(),
      unit: (json['unit'] as String?) ?? '',
      reportedAt: _date(json['reported_at']) ?? DateTime.now(),
      reportedBy: json['reported_by'] as String,
      zip: json['zip'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'canonical_slug': canonicalSlug,
        'store_slug': storeSlug,
        'price': price,
        'unit': unit,
        'reported_at': reportedAt.toUtc().toIso8601String(),
        'reported_by': reportedBy,
        'zip': zip,
      };
}
