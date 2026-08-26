import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import '../../catalog/domain/entities/canonical_item.dart';
import '../../catalog/domain/repositories/catalog_repository.dart';
import '../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../pricing/data/datasources/price_local_datasource.dart';
import '../../pricing/data/models/price_report_model.dart';
import '../../pricing/domain/price_selection.dart';
import '../../pricing/domain/zip_relevance.dart';
import '../../stores/domain/entities/store.dart';
import '../../stores/domain/repositories/stores_repository.dart';
import 'dto/remote_price_report.dart';

class PriceSyncSummary {
  final int pushed;
  final int pulled;

  const PriceSyncSummary({this.pushed = 0, this.pulled = 0});
}

/// Community prices: push this user's reports, pull reports from the same ZIP
/// prefix.
///
/// ZIP prefix, not full ZIP, so two shoppers in the same city still compare
/// even if they live in neighboring codes. Reports with no ZIP are never
/// ingested from other people — unknown area is treated as "somewhere else".
class PriceSyncService {
  final SupabaseClient? _client;
  final PriceLocalDataSource _local;
  final CatalogRepository _catalog;
  final StoresRepository _stores;
  final PreferencesLocalDataSource _preferences;

  PriceSyncService(
    this._client,
    this._local,
    this._catalog,
    this._stores,
    this._preferences,
  );

  Future<Result<PriceSyncSummary>> sync() async {
    final client = _client;
    if (client == null) {
      return const Result.err(ValidationFailure('Sync is not available.'));
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(UnauthorizedFailure('Sign in to sync prices.'));
    }

    try {
      final maps = await _maps();
      final prefs = await _preferences.load();
      final userZip = prefs.priceZip;
      final deviceId = prefs.deviceId;

      final pushed = await _push(
        client,
        userId: userId,
        deviceId: deviceId,
        idToSlug: maps.idToSlug,
        storeIdToSlug: maps.storeIdToSlug,
      );
      final pulled = await _pull(
        client,
        userId: userId,
        userZip: userZip,
        slugToId: maps.slugToId,
        storeSlugToId: maps.storeSlugToId,
      );
      return Result.ok(PriceSyncSummary(pushed: pushed, pulled: pulled));
    } on PostgrestException catch (e, st) {
      logger.error('Price sync rejected by the server', e, st);
      return Result.err(NetworkFailure('Price sync failed. Try again.', cause: e));
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not save synced prices', cause: e));
    } catch (e, st) {
      logger.warning('Price sync could not reach the server: $e');
      logger.debug(st.toString());
      return Result.err(
        NetworkFailure('No connection. Price sync will retry.', cause: e),
      );
    }
  }

  /// Only this user's rows. Re-pushing someone else's report would fail RLS
  /// (`reported_by = auth.uid()`) and is the wrong ownership story anyway.
  Future<int> _push(
    SupabaseClient client, {
    required String userId,
    required String? deviceId,
    required Map<int, String> idToSlug,
    required Map<int, String> storeIdToSlug,
  }) async {
    final locals = await _local.allReports();
    final rows = <Map<String, dynamic>>[];

    for (final report in locals) {
      final mine = report.reportedBy == userId ||
          (deviceId != null && report.reportedBy == deviceId);
      if (!mine) continue;
      if (report.deletedAt != null) continue;

      final canonicalSlug = idToSlug[report.canonicalItemId];
      final storeSlug = storeIdToSlug[report.storeId];
      // Unresolved or unknown-store reports stay device-local: they have no
      // shared identity to attach to on the other side.
      if (canonicalSlug == null || storeSlug == null) continue;

      rows.add(
        RemotePriceReport(
          id: report.publicId,
          canonicalSlug: canonicalSlug,
          storeSlug: storeSlug,
          price: report.price,
          unit: report.unit,
          reportedAt: report.reportedAt,
          reportedBy: userId,
          zip: normalizeZip(report.zip),
        ).toJson(),
      );
    }

    if (rows.isEmpty) return 0;
    await client.from('price_reports').upsert(rows);
    return rows.length;
  }

  Future<int> _pull(
    SupabaseClient client, {
    required String userId,
    required String? userZip,
    required Map<String, int> slugToId,
    required Map<String, int> storeSlugToId,
  }) async {
    final prefix = zipPrefix(userZip);
    // No ZIP → pull only this user's own reports (other devices), never the
    // whole table. Mixing unscoped community prices is how Ohio milk shows up
    // in Georgia.
    final query = prefix == null
        ? client.from('price_reports').select().eq('reported_by', userId)
        : client.from('price_reports').select().or(
              'zip.like.$prefix%,reported_by.eq.$userId',
            );

    final rows = await query;
    final cutoff = DateTime.now().subtract(kPriceMaxAge);
    final incoming = <PriceReportModel>[];

    for (final row in rows) {
      final remote = RemotePriceReport.fromJson(row);
      if (remote.reportedAt.isBefore(cutoff)) continue;

      final isOwn = remote.reportedBy == userId;
      if (!isOwn &&
          !reportMatchesArea(reportZip: remote.zip, userZip: userZip)) {
        continue;
      }

      final canonicalId = slugToId[remote.canonicalSlug];
      final storeId = storeSlugToId[remote.storeSlug];
      if (canonicalId == null || storeId == null) continue;

      incoming.add(
        PriceReportModel()
          ..publicId = remote.id
          ..canonicalItemId = canonicalId
          ..storeId = storeId
          ..price = remote.price
          ..unit = remote.unit
          ..reportedAt = remote.reportedAt
          ..reportedBy = remote.reportedBy
          ..zip = remote.zip,
      );
    }

    await _local.putAll(incoming);
    return incoming.length;
  }

  Future<_Maps> _maps() async {
    final catalog = await _catalog.getAll();
    final stores = await _stores.getStores();

    final items = catalog.when(
      ok: (v) => v,
      err: (_) => const <CanonicalItem>[],
    );
    final storeList = stores.when(
      ok: (v) => v,
      err: (_) => const <Store>[],
    );

    return _Maps(
      idToSlug: {for (final i in items) i.id: i.slug},
      slugToId: {for (final i in items) i.slug: i.id},
      storeIdToSlug: {for (final s in storeList) s.id: s.slug},
      storeSlugToId: {for (final s in storeList) s.slug: s.id},
    );
  }
}

class _Maps {
  final Map<int, String> idToSlug;
  final Map<String, int> slugToId;
  final Map<int, String> storeIdToSlug;
  final Map<String, int> storeSlugToId;

  const _Maps({
    required this.idToSlug,
    required this.slugToId,
    required this.storeIdToSlug,
    required this.storeSlugToId,
  });
}
