import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../../images/presentation/providers/images_di.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../../domain/entities/grocery_item.dart';
import 'lists_di.dart';

/// Holds the *outcome* of the last write action (idle/loading/error) so a
/// modal or button can show a spinner / inline error without owning any
/// business logic itself. This is the direct replacement for "isolated
/// controllers and listeners" from the old StatefulWidget approach —
/// same separation of concerns, but centralized, disposed automatically,
/// and unit-testable without pumping a widget tree.
class ListActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {} // idle state

  Future<bool> createList({
    required String name,
    required ScheduleFrequency frequency,
    DateTime? explicitDate,
  }) async {
    state = const AsyncLoading();
    final usecase = ref.read(createScheduledListProvider);
    final result = await usecase(name: name, frequency: frequency, explicitDate: explicitDate);
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> addItem({
    required String listId,
    required String name,
    required double quantity,
    required ItemUnit unit,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(listsRepositoryProvider);
    final res = await ref.read(imageRepositoryProvider).search(name);

    final String? thatUrl = res.when(
      ok: (images) => images.isNotEmpty ? images.last.thumbnailUrl : null,
      err: (_) => null
    );

    final result = await repo.addItem(
      listId: listId,
      name: name,
      quantity: quantity,
      unitIndex: unit.index,
      imageUrl: thatUrl
    );
    return _settle(result);
  }

  /// Used for both inline-edit commits and the checkbox toggle — same
  /// entry point, so there is exactly one code path that can produce the
  /// "checkbox bugs" the old app suffered from, and it's covered by tests.
  Future<bool> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? quantity,
    ItemUnit? unit,
    bool? isChecked,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(listsRepositoryProvider);
    final result = await repo.updateItem(
      listId: listId,
      itemId: itemId,
      name: name,
      quantity: quantity,
      unitIndex: unit?.index,
      isChecked: isChecked,
    );
    return _settle(result);
  }

  Future<bool> deleteItem({required String listId, required String itemId}) async {
    state = const AsyncLoading();
    final repo = ref.read(listsRepositoryProvider);
    final result = await repo.deleteItem(listId: listId, itemId: itemId);
    return _settle(result);
  }

  Future<bool> deleteList(String listId) async {
    state = const AsyncLoading();
    final repo = ref.read(listsRepositoryProvider);
    final result = await repo.deleteList(listId);
    return _settle(result);
  }

  bool _settle<T>(Result<T> result) {
    return result.when(
      ok: (_) {
        state = const AsyncData(null);
        return true;
      },
      err: (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }
}

final listActionsControllerProvider =
    AsyncNotifierProvider<ListActionsController, void>(ListActionsController.new);
