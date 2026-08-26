import 'package:equatable/equatable.dart';

/// A physical grocery location the user can track and report prices for.
///
/// Place-level (not just "Walmart" as a brand): community prices are only
/// useful when they are about a real aisle the shopper visits.
class Store extends Equatable {
  /// Local Isar id.
  final int id;

  /// Stable identity from the seed data, used when reports sync.
  final String slug;

  /// Chain display name ("Walmart", "Kroger").
  final String name;

  /// Brand key shared across locations of the same chain ("walmart").
  final String chainSlug;

  final String? addressLine;
  final String? city;
  final String? state;
  final String? zip;

  final double? latitude;
  final double? longitude;

  /// Whether the user shops here. Gates comparison filters and report defaults.
  final bool trackedByUser;

  final String? logoAssetPath;

  const Store({
    required this.id,
    required this.slug,
    required this.name,
    required this.chainSlug,
    required this.trackedByUser,
    this.addressLine,
    this.city,
    this.state,
    this.zip,
    this.latitude,
    this.longitude,
    this.logoAssetPath,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// True when [addressLine] is a real street, not an OSM/seed placeholder.
  bool get hasStreetAddress {
    final line = addressLine?.trim() ?? '';
    if (line.isEmpty) return false;
    final lower = line.toLowerCase();
    if (lower.startsWith('store in ')) return false;
    if (lower == 'unnamed road' || lower.startsWith('unnamed ')) return false;
    return true;
  }

  String get cityState {
    return [
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
    ].join(', ');
  }

  String get cityStateZip {
    final place = cityState;
    final z = zip?.trim();
    if (place.isEmpty) return z ?? '';
    if (z == null || z.isEmpty) return place;
    return '$place $z';
  }

  /// Compact chip label: "Walmart · Apache Junction, AZ".
  String get listLabel {
    final place = cityState;
    if (place.isEmpty) return name;
    return '$name · $place';
  }

  /// Street + city/ST/ZIP. Skips placeholder lines like "Store in Atlanta".
  String get subtitle {
    final parts = <String>[
      if (hasStreetAddress) addressLine!.trim(),
      if (cityStateZip.isNotEmpty) cityStateZip,
    ];
    final seen = <String>{};
    final unique = <String>[];
    for (final part in parts) {
      final key = part.toLowerCase();
      if (seen.add(key)) unique.add(part);
    }
    return unique.join(' · ');
  }

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        chainSlug,
        addressLine,
        city,
        state,
        zip,
        latitude,
        longitude,
        trackedByUser,
        logoAssetPath,
      ];
}
