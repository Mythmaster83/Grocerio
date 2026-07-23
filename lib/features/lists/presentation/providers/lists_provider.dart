import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/grocery_list.dart';
import 'lists_di.dart';

/// Streams every list, live. This is the "real-time updates" requirement:
/// any write anywhere (inline edit, voice input, checkbox toggle) goes
/// through the repository, which re-emits from Isar's watch(), which
/// flows straight here with zero manual refresh calls anywhere in the UI.
///
/// UI usage: `ref.watch(listsStreamProvider)` returns AsyncValue<List<GroceryList>> —
/// screens pattern-match .when(data:, loading:, error:) and never touch Isar,
/// Riverpod internals beyond `ref`, or business logic.
final listsStreamProvider = StreamProvider.autoDispose<List<GroceryList>>((ref) {
  final repository = ref.watch(listsRepositoryProvider);
  return repository.watchLists();
});

/// Single list detail stream, parameterized by id. `.family` + `.autoDispose`
/// means navigating away from a list detail screen frees its subscription
/// automatically — no manual dispose() bookkeeping in the widget.
final listDetailStreamProvider =
    StreamProvider.autoDispose.family<GroceryList?, String>((ref, listId) {
  final repository = ref.watch(listsRepositoryProvider);
  return repository.watchList(listId);
});
