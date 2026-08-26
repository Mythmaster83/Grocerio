import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle;
import '../../../../core/utils/app_logger.dart';
import '../../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../../stores/data/datasources/stores_local_datasource.dart';
import '../../../stores/data/models/store_model.dart';
import '../../domain/entities/item_category.dart';
import '../datasources/catalog_local_datasource.dart';
import '../models/canonical_item_model.dart';

const catalogSeedAssetPath = 'assets/catalog/catalog_seed.json';
const usStoresSeedAssetPath = 'assets/catalog/us_stores_seed.json';

/// Bump to re-import catalog/stores on existing installs.
/// v2: place-level US store directory replaces 3 brand-only rows.
/// v3: drop fake "N Main St" lines; metro-area labels + real GPS distances.
/// v4: OpenStreetMap supermarket POIs (street/ZIP/lat/lng) for metro radii.
const catalogSeedVersion = 4;

/// Loads the bundled catalog and US store directory into Isar once per version.
class CatalogSeedService {
  final CatalogLocalDataSource _catalog;
  final StoresLocalDataSource _stores;
  final PreferencesLocalDataSource _preferences;
  final AssetBundle _bundle;

  CatalogSeedService({
    required CatalogLocalDataSource catalog,
    required StoresLocalDataSource stores,
    required PreferencesLocalDataSource preferences,
    required AssetBundle bundle,
  })  : _catalog = catalog,
        _stores = stores,
        _preferences = preferences,
        _bundle = bundle;

  /// Returns true when data was written. Never throws: a broken seed asset
  /// must degrade to "no price matching" rather than a launch crash.
  Future<bool> seedIfNeeded() async {
    try {
      final prefs = await _preferences.load();
      if (prefs.catalogSeedVersion >= catalogSeedVersion) return false;

      final catalogRaw = await _bundle.loadString(catalogSeedAssetPath);
      final catalogDecoded = jsonDecode(catalogRaw) as Map<String, dynamic>;
      final items = _parseItems(catalogDecoded['items']);
      if (items.isEmpty) {
        logger.error('Catalog seed contained no items; skipping');
        return false;
      }

      final storesRaw = await _bundle.loadString(usStoresSeedAssetPath);
      final storesDecoded = jsonDecode(storesRaw) as Map<String, dynamic>;
      final stores = _parseStores(storesDecoded['stores']);
      if (stores.isEmpty) {
        logger.error('US stores seed contained no stores; skipping');
        return false;
      }

      await _putStoresPreservingTracking(stores);
      await _catalog.putAll(items);

      prefs.catalogSeedVersion = catalogSeedVersion;
      await _preferences.save(prefs);
      logger.info(
        'Seeded catalog v$catalogSeedVersion: '
        '${items.length} items, ${stores.length} stores',
      );
      return true;
    } catch (e, st) {
      logger.error('Catalog seeding failed', e, st);
      return false;
    }
  }

  Future<void> _putStoresPreservingTracking(List<StoreModel> seeded) async {
    final existing = await _stores.getAll();
    final trackedBySlug = {
      for (final store in existing)
        if (store.trackedByUser) store.slug: true,
    };
    final seededSlugs = {for (final store in seeded) store.slug};

    for (final store in seeded) {
      store.trackedByUser = trackedBySlug[store.slug] ?? false;
    }

    // Synthetic metro slugs change when we import OSM POIs — rematch by
    // chain + nearest pin so users keep a tracked store of that brand.
    final rematchedSlugs = <String>{};
    for (final store in existing) {
      if (!store.trackedByUser) continue;
      if (seededSlugs.contains(store.slug)) continue;
      if (store.latitude == null || store.longitude == null) continue;

      StoreModel? best;
      var bestMiles = double.infinity;
      for (final candidate in seeded) {
        if (candidate.chainSlug != store.chainSlug) continue;
        if (candidate.trackedByUser) continue;
        if (rematchedSlugs.contains(candidate.slug)) continue;
        if (candidate.latitude == null || candidate.longitude == null) {
          continue;
        }
        final miles = _milesBetween(
          store.latitude!,
          store.longitude!,
          candidate.latitude!,
          candidate.longitude!,
        );
        if (miles < bestMiles) {
          bestMiles = miles;
          best = candidate;
        }
      }
      if (best != null) {
        best.trackedByUser = true;
        rematchedSlugs.add(best.slug);
      }
    }

    await _stores.clearAll();
    await _stores.putAll(seeded);
  }

  static double _milesBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthMi = 3958.8;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthMi * c;
  }

  static double _toRad(double deg) => deg * math.pi / 180.0;

  List<StoreModel> _parseStores(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final entry in raw.whereType<Map<String, dynamic>>())
        if ((entry['slug'] as String?)?.trim().isNotEmpty ?? false)
          StoreModel()
            ..slug = (entry['slug'] as String).trim()
            ..name = (entry['name'] as String?)?.trim() ??
                (entry['slug'] as String).trim()
            ..chainSlug = (entry['chainSlug'] as String?)?.trim() ??
                (entry['slug'] as String).trim()
            ..addressLine = (entry['addressLine'] as String?)?.trim()
            ..city = (entry['city'] as String?)?.trim()
            ..state = (entry['state'] as String?)?.trim()
            ..zip = (entry['zip'] as String?)?.trim()
            ..latitude = (entry['lat'] as num?)?.toDouble()
            ..longitude = (entry['lng'] as num?)?.toDouble()
            // Place-level directory: nothing tracked until the user picks
            // nearby stores. Auto-tracking hundreds of locations would make
            // every comparison grid unusable.
            ..trackedByUser = false,
    ];
  }

  List<CanonicalItemModel> _parseItems(Object? raw) {
    if (raw is! List) return const [];
    final items = <CanonicalItemModel>[];
    for (final entry in raw.whereType<Map<String, dynamic>>()) {
      final slug = (entry['slug'] as String?)?.trim();
      final name = (entry['name'] as String?)?.trim();
      if (slug == null || slug.isEmpty || name == null || name.isEmpty) continue;

      final aliases = <String>{
        name.toLowerCase(),
        for (final alias in (entry['aliases'] as List?) ?? const [])
          if (alias is String && alias.trim().isNotEmpty)
            alias.trim().toLowerCase(),
      };

      items.add(
        CanonicalItemModel()
          ..slug = slug
          ..name = name
          ..nameLower = name.toLowerCase()
          ..category = ItemCategoryDbX.fromDomain(
            ItemCategoryX.fromName(entry['category'] as String? ?? 'other'),
          )
          ..aliasKeywords = aliases.toList(growable: false),
      );
    }
    return items;
  }
}
