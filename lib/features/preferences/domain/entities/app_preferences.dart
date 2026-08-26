import 'package:equatable/equatable.dart';

class AppPreferences extends Equatable {
  final int themeModeIndex;
  final int accentColorValue;
  final String fontFamily;
  final double textScale; // 0.85 - 1.4, clamped

  /// Units the user typed themselves ("bunch", "bottle", …). Kept here rather
  /// than derived from existing items so a saved unit survives deleting the
  /// item it was first used on.
  final List<String> customUnits;

  /// Version of the bundled catalog already written to Isar. 0 means "never
  /// seeded". A version rather than a bool so shipping a bigger catalog later
  /// re-runs the seeder exactly once instead of never.
  final int catalogSeedVersion;

  /// Store the price-report sheet should default to, remembered across reports
  /// because re-picking the same store every time is the main friction in
  /// contributing prices.
  final String? lastReportedStoreSlug;

  /// Random per-install id stamped on price reports so a bad contributor can be
  /// identified without knowing who they are. Replaced by the account id once
  /// sign-in exists.
  final String? deviceId;

  /// Shopper's ZIP code. Without this, incoming community prices cannot be
  /// scoped to a region, so they are not pulled at all.
  final String? priceZip;

  const AppPreferences({
    required this.themeModeIndex,
    required this.accentColorValue,
    required this.fontFamily,
    required this.textScale,
    this.customUnits = const [],
    this.catalogSeedVersion = 0,
    this.lastReportedStoreSlug,
    this.deviceId,
    this.priceZip,
  });

  factory AppPreferences.defaults() => const AppPreferences(
        themeModeIndex: 0,
        accentColorValue: 0xFF2F6F4F,
        fontFamily: 'Inter',
        textScale: 1.0,
        customUnits: [],
        catalogSeedVersion: 0,
      );

  AppPreferences copyWith({
    int? themeModeIndex,
    int? accentColorValue,
    String? fontFamily,
    double? textScale,
    List<String>? customUnits,
    int? catalogSeedVersion,
    String? lastReportedStoreSlug,
    String? deviceId,
    String? priceZip,
    bool clearPriceZip = false,
  }) {
    return AppPreferences(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      textScale: (textScale ?? this.textScale).clamp(0.85, 1.4),
      customUnits: customUnits ?? this.customUnits,
      catalogSeedVersion: catalogSeedVersion ?? this.catalogSeedVersion,
      lastReportedStoreSlug:
          lastReportedStoreSlug ?? this.lastReportedStoreSlug,
      deviceId: deviceId ?? this.deviceId,
      priceZip: clearPriceZip ? null : (priceZip ?? this.priceZip),
    );
  }

  @override
  List<Object?> get props => [
        themeModeIndex,
        accentColorValue,
        fontFamily,
        textScale,
        customUnits,
        catalogSeedVersion,
        lastReportedStoreSlug,
        deviceId,
        priceZip,
      ];
}
