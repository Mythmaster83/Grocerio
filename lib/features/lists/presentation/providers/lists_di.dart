import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/isar_provider.dart';
import '../../../notifications/presentation/providers/notifications_di.dart';
import '../../data/datasources/lists_local_datasource.dart';
import '../../data/repositories/lists_repository_impl.dart';
import '../../domain/repositories/lists_repository.dart';
import '../../domain/usecases/complete_shopping.dart';
import '../../domain/usecases/create_scheduled_list.dart';
import '../../domain/usecases/reconcile_schedules.dart';

/// Dependency wiring for the `lists` feature. Kept next to the providers
/// that consume it rather than in one giant global DI file — with
/// feature-first architecture, DI should be feature-first too, or every
/// new feature forces a merge-conflict-prone edit to a shared file.
final listsLocalDataSourceProvider = Provider<ListsLocalDataSource>((ref) {
  return ListsLocalDataSource(ref.watch(isarProvider));
});

final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  return ListsRepositoryImpl(ref.watch(listsLocalDataSourceProvider));
});

final createScheduledListProvider = Provider<CreateScheduledList>((ref) {
  return CreateScheduledList(ref.watch(listsRepositoryProvider));
});

final completeShoppingProvider = Provider<CompleteShopping>((ref) {
  return CompleteShopping(ref.watch(listsRepositoryProvider));
});

final reconcileSchedulesUsecaseProvider = Provider<ReconcileSchedules>((ref) {
  return ReconcileSchedules(ref.watch(listsRepositoryProvider));
});

/// Runs once per ProviderScope lifetime (typically once per app open).
final reconcileSchedulesProvider = FutureProvider<void>((ref) async {
  final result = await ref.read(reconcileSchedulesUsecaseProvider)();
  await result.when(
    ok: (changes) async {
      final scheduler = ref.read(listNotificationSchedulerProvider);
      for (final change in changes) {
        if (change.missed) {
          await scheduler.notifyMissed(change.list);
        }
        if (change.advanced) {
          await scheduler.scheduleForList(change.list);
        }
      }
    },
    err: (failure) async {
      throw failure;
    },
  );
});
