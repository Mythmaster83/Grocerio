// The Storage client exports its own StorageException; this app's storage
// failures are the Isar ones, so the network SDK's name is hidden here.
import 'package:supabase_flutter/supabase_flutter.dart' hide StorageException;
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import '../../catalog/domain/repositories/catalog_repository.dart';
import '../../lists/data/models/grocery_list_model.dart';
import '../domain/list_merge.dart';
import '../domain/sync_state.dart';
import 'dto/remote_list.dart';
import 'sync_local_datasource.dart';

/// Pull-then-push sync for lists and their items.
///
/// Local Isar remains the source of truth the UI reads, so every screen keeps
/// working with no network and sync is a background reconciliation step rather
/// than a load-bearing dependency. Pull runs first so a delete (tombstone)
/// written by another device is applied before this device upserts; push then
/// uploads the merged local state. Live upserts omit null `deleted_at` so they
/// cannot wipe a peer's tombstone on the server.
class ListsSyncService {
  final SupabaseClient? _client;
  final SyncLocalDataSource _local;
  final CatalogRepository _catalog;

  ListsSyncService(this._client, this._local, this._catalog);

  Future<Result<SyncSummary>> sync() async {
    final client = _client;
    if (client == null) {
      return const Result.err(ValidationFailure('Sync is not available.'));
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      return const Result.err(UnauthorizedFailure('Sign in to sync.'));
    }

    try {
      await _local.claimUnownedLists(userId);
      final catalog = await _catalogMaps();

      // Pull first so a tombstone written by another device is merged in
      // before this device upserts. Combined with omitting null deleted_at on
      // push, that stops a live peer from resurrecting a deleted list.
      final pull = await _pull(client, catalog.slugToId);
      final pushed = await _push(client, userId, catalog.idToSlug);
      await _local.purgeTombstones(DateTime.now().subtract(kTombstoneRetention));

      if (pull.overwrites > 0) {
        logger.info(
          'Sync replaced ${pull.overwrites} local row(s) with newer remote copies',
        );
      }
      return Result.ok(
        SyncSummary(
          pushedLists: pushed,
          pulledLists: pull.pulledLists,
          overwrites: pull.overwrites,
        ),
      );
    } on PostgrestException catch (e, st) {
      logger.error('Sync rejected by the server', e, st);
      return Result.err(NetworkFailure('Sync failed. Try again.', cause: e));
    } on StorageException catch (e, st) {
      logger.error(e.message, e.cause, st);
      return Result.err(StorageFailure('Could not save synced lists', cause: e));
    } catch (e, st) {
      // Offline is the common case here, and it is not worth alarming about.
      logger.warning('Sync could not reach the server: $e');
      logger.debug(st.toString());
      return Result.err(NetworkFailure('No connection. Sync will retry.', cause: e));
    }
  }

  /// Every list is pushed on every sync rather than tracking dirty rows. With a
  /// handful of lists per user the payload is trivial, and upserts are
  /// idempotent, so this trades bandwidth for removing a whole class of
  /// "row was edited but never marked dirty" bugs.
  Future<int> _push(
    SupabaseClient client,
    String userId,
    Map<int, String> idToSlug,
  ) async {
    final locals = await _local.allLists();
    if (locals.isEmpty) return 0;

    final owned = <GroceryListModel>[];
    final shared = <GroceryListModel>[];
    for (final list in locals) {
      if ((list.ownerId ?? userId) == userId) {
        owned.add(list);
      } else {
        shared.add(list);
      }
    }

    final tombstones = <GroceryListModel>[];
    final liveOwned = <GroceryListModel>[];
    for (final list in owned) {
      if (list.deletedAt != null) {
        tombstones.add(list);
      } else {
        liveOwned.add(list);
      }
    }
    for (final list in shared) {
      if (list.deletedAt != null) tombstones.add(list);
    }

    // Tombstones first so a peer that pulls mid-push cannot miss the delete
    // and re-upload a live copy. Owner id stays the original owner — swapping
    // it to this user would fail RLS on a shared list.
    if (tombstones.isNotEmpty) {
      await client.from('lists').upsert(
            tombstones
                .map(
                  (l) => RemoteList.fromLocal(
                    l,
                    ownerId: l.ownerId ?? userId,
                  ).toJson(),
                )
                .toList(growable: false),
            onConflict: 'id',
          );
    }

    if (liveOwned.isNotEmpty) {
      await client.from('lists').upsert(
            liveOwned
                .map(
                  (l) => RemoteList.fromLocal(
                    l,
                    ownerId: l.ownerId ?? userId,
                  ).toJson(),
                )
                .toList(growable: false),
            onConflict: 'id',
          );
    }

    // Lists shared *with* this user get their items pushed but not the live
    // list row: the insert policy requires owner_id = auth.uid(), and letting
    // members rename or reschedule someone else's list is not what sharing
    // promises anyway. Tombstoned shared rows are pushed above so a member
    // delete still reaches the owner.
    final itemRows = <Map<String, dynamic>>[];
    for (final list in [...owned, ...shared]) {
      for (final item in list.items) {
        final slug = item.canonicalItemId == null
            ? null
            : idToSlug[item.canonicalItemId!];
        itemRows.add(
          RemoteListItem.fromLocal(item, list.publicId, canonicalSlug: slug)
              .toJson(),
        );
      }
    }
    if (itemRows.isNotEmpty) {
      await client.from('list_items').upsert(itemRows, onConflict: 'id');
    }

    return owned.length;
  }

  Future<_PullResult> _pull(
    SupabaseClient client,
    Map<String, int> slugToId,
  ) async {
    // No `updated_at > watermark` filter: full pulls avoid trusting the device
    // clock against the server's, and the row count per user is small.
    // Row-level security is what scopes these two queries to lists this user
    // owns or is a member of.
    final listRows = await client.from('lists').select();
    final itemRows = await client.from('list_items').select();

    final itemsByList = <String, List<RemoteListItem>>{};
    for (final row in itemRows) {
      final item = RemoteListItem.fromJson(row);
      itemsByList.putIfAbsent(item.listId, () => []).add(item);
    }

    final merged = <GroceryListModel>[];
    var overwrites = 0;
    for (final row in listRows) {
      final remote = RemoteList.fromJson(
        row,
        items: itemsByList[row['id']] ?? const [],
      );
      final local = await _local.findByPublicId(remote.id);
      final result = mergeList(
        local: local,
        remote: remote,
        canonicalIdForSlug: (slug) => slugToId[slug],
      );
      merged.add(result.list);
      overwrites += result.overwrites;
    }

    await _local.putMerged(merged);
    return _PullResult(merged.length, overwrites);
  }

  Future<_CatalogMaps> _catalogMaps() async {
    final result = await _catalog.getAll();
    return result.when(
      ok: (items) => _CatalogMaps(
        {for (final i in items) i.id: i.slug},
        {for (final i in items) i.slug: i.id},
      ),
      // A missing catalog costs price links on synced items, not the sync.
      err: (failure) {
        logger.warning('Sync running without a catalog map: ${failure.message}');
        return const _CatalogMaps({}, {});
      },
    );
  }
}

class _PullResult {
  final int pulledLists;
  final int overwrites;
  const _PullResult(this.pulledLists, this.overwrites);
}

class _CatalogMaps {
  final Map<int, String> idToSlug;
  final Map<String, int> slugToId;
  const _CatalogMaps(this.idToSlug, this.slugToId);
}
