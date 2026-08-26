import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/backend/supabase_config.dart';
import '../../../account/presentation/providers/account_di.dart';
import '../../../catalog/presentation/providers/catalog_di.dart';
import '../../../../core/di/isar_provider.dart';
import '../../../lists/presentation/providers/lists_provider.dart';
import '../../../preferences/data/datasources/preferences_local_datasource.dart';
import '../../../pricing/presentation/providers/pricing_di.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../../data/lists_sync_service.dart';
import '../../data/price_sync_service.dart';
import '../../data/sync_local_datasource.dart';
import '../../domain/sync_state.dart';

final syncLocalDataSourceProvider = Provider<SyncLocalDataSource>((ref) {
  return SyncLocalDataSource(ref.watch(isarProvider));
});

final listsSyncServiceProvider = Provider<ListsSyncService>((ref) {
  return ListsSyncService(
    SupabaseConfig.clientOrNull,
    ref.watch(syncLocalDataSourceProvider),
    ref.watch(catalogRepositoryProvider),
  );
});

final priceSyncServiceProvider = Provider<PriceSyncService>((ref) {
  return PriceSyncService(
    SupabaseConfig.clientOrNull,
    ref.watch(priceLocalDataSourceProvider),
    ref.watch(catalogRepositoryProvider),
    ref.watch(storesRepositoryProvider),
    PreferencesLocalDataSource(ref.watch(isarProvider)),
  );
});

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncState>(SyncStatusNotifier.new);

class SyncStatusNotifier extends Notifier<SyncState> {
  Timer? _debounce;
  Timer? _heartbeat;
  RealtimeChannel? _listsChannel;
  bool _rerun = false;

  @override
  SyncState build() {
    ref.listen(currentUserProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user == null) {
        stopHeartbeat();
        state = const SyncState(phase: SyncPhase.offline);
      } else {
        // Signing in is also the first sync: it is what uploads everything the
        // user created while account-less.
        scheduleMicrotask(syncNow);
        startHeartbeat();
      }
    }, fireImmediately: true);

    ref.onDispose(() {
      _debounce?.cancel();
      stopHeartbeat();
    });
    return const SyncState();
  }

  /// Pull while the app is in the foreground so a delete on the other phone
  /// shows up here without waiting for a local write.
  void startHeartbeat() {
    if (!ref.read(backendAvailableProvider)) return;
    if (ref.read(currentUserProvider).valueOrNull == null) return;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.isSyncing) unawaited(syncNow());
    });
    _listenRemoteListChanges();
  }

  void stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
    final channel = _listsChannel;
    _listsChannel = null;
    if (channel != null) unawaited(channel.unsubscribe());
  }

  /// Postgres changes on `lists` (including tombstones) trigger an immediate
  /// pull on the other phone. Requires migration 0005.
  void _listenRemoteListChanges() {
    final client = SupabaseConfig.clientOrNull;
    if (client == null || _listsChannel != null) return;
    _listsChannel = client
        .channel('grocerio-lists')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'lists',
          callback: (_) => requestSync(immediate: true),
        )
        .subscribe();
  }

  Future<void> syncNow() async {
    if (state.isSyncing) {
      // A delete (or any write) that lands mid-sync must not be dropped.
      _rerun = true;
      return;
    }
    _debounce?.cancel();
    state = state.copyWith(phase: SyncPhase.syncing, clearError: true);

    final listsResult = await ref.read(listsSyncServiceProvider).sync();
    final priceResult = await ref.read(priceSyncServiceProvider).sync();
    // Tracked stores are best-effort: failure must not block list sync UX.
    await ref.read(storesRepositoryProvider).syncTrackedWithAccount();

    // Lists are the user-visible failure; a price-only miss still counts as
    // synced so a flaky community table doesn't look like the whole account
    // broke. The price error is logged inside PriceSyncService.
    state = listsResult.when(
      ok: (summary) => SyncState(
        phase: SyncPhase.synced,
        lastSyncedAt: DateTime.now(),
        lastSummary: summary,
      ),
      err: (failure) => state.copyWith(
        phase: SyncPhase.failed,
        error: failure.message,
      ),
    );
    priceResult.when(ok: (_) {}, err: (_) {});

    if (_rerun) {
      _rerun = false;
      await syncNow();
    }
  }

  /// Coalesces the burst of writes a single user action produces (checking off
  /// five items is five list writes) into one round trip.
  ///
  /// [immediate] skips the debounce — used for deletes so the tombstone leaves
  /// this device before the other phone's next pull.
  void requestSync({bool immediate = false}) {
    if (!ref.read(backendAvailableProvider)) return;
    _debounce?.cancel();
    if (immediate) {
      scheduleMicrotask(syncNow);
      return;
    }
    _debounce = Timer(const Duration(seconds: 3), syncNow);
  }
}

/// Triggers a debounced sync whenever local lists change.
///
/// Watching the stream instead of calling `requestSync` from each write path
/// keeps sync out of the repository entirely — there is no way to add a new
/// mutation and forget to sync it.
final syncOnWriteProvider = Provider<void>((ref) {
  var firstLists = true;
  var firstPrices = true;
  ref.listen(listsStreamProvider, (previous, next) {
    if (!next.hasValue) return;
    // The first emission is just the initial read, not a write.
    if (firstLists) {
      firstLists = false;
      return;
    }
    ref.read(syncStatusProvider.notifier).requestSync();
  });
  ref.listen(priceReportsTickProvider, (previous, next) {
    if (firstPrices) {
      firstPrices = false;
      return;
    }
    ref.read(syncStatusProvider.notifier).requestSync();
  });
});
