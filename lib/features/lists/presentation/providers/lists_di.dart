import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/isar_provider.dart';
import '../../data/datasources/lists_local_datasource.dart';
import '../../data/repositories/lists_repository_impl.dart';
import '../../domain/repositories/lists_repository.dart';
import '../../domain/usecases/create_scheduled_list.dart';

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
