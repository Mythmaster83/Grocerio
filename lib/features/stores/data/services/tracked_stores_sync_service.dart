import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/result.dart';
import '../datasources/stores_local_datasource.dart';

/// Pushes / pulls which store slugs this account tracks.
///
/// Local Isar still holds the full directory and the on-device flags. This
/// service mirrors those flags to Supabase so a new device can restore them
/// after sign-in.
class TrackedStoresSyncService {
  final SupabaseClient? _client;
  final StoresLocalDataSource _local;

  TrackedStoresSyncService(this._client, this._local);

  bool get isAvailable => _client != null;

  /// Upload every locally tracked slug, then apply the union onto Isar.
  ///
  /// Turning a store off deletes the remote row (see [pushTrackedChange]).
  Future<Result<void>> sync() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) {
      return const Result.ok(null);
    }

    try {
      final local = await _local.getAll();
      final localTracked = local
          .where((s) => s.trackedByUser)
          .map((s) => s.slug)
          .toSet();

      final remoteRows = await client
          .from('user_tracked_stores')
          .select('store_slug')
          .eq('user_id', userId);
      final remoteTracked = <String>{
        for (final row in remoteRows as List)
          if (row is Map && row['store_slug'] is String)
            row['store_slug'] as String,
      };

      final merged = {...localTracked, ...remoteTracked};

      final toInsert = localTracked.difference(remoteTracked);
      if (toInsert.isNotEmpty) {
        await client.from('user_tracked_stores').upsert([
          for (final slug in toInsert)
            {
              'user_id': userId,
              'store_slug': slug,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
        ]);
      }

      await _local.setTrackedBySlugs(merged);
      return const Result.ok(null);
    } catch (e, st) {
      logger.error('Tracked stores sync failed', e, st);
      return Result.err(
        NetworkFailure('Could not sync tracked stores.', cause: e),
      );
    }
  }

  /// Keep the cloud row in lockstep when the user toggles one store.
  Future<void> pushTrackedChange({
    required String storeSlug,
    required bool tracked,
  }) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      if (tracked) {
        await client.from('user_tracked_stores').upsert({
          'user_id': userId,
          'store_slug': storeSlug,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await client
            .from('user_tracked_stores')
            .delete()
            .eq('user_id', userId)
            .eq('store_slug', storeSlug);
      }
    } catch (e, st) {
      // Local toggle already succeeded; cloud catch-up happens on next sync.
      logger.error('Tracked store push failed', e, st);
    }
  }
}
