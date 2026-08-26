import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/lists/data/models/grocery_item_model.dart';
import 'package:grocer/features/lists/data/models/grocery_list_model.dart';
import 'package:grocer/features/sync/data/dto/remote_list.dart';
import 'package:grocer/features/sync/domain/list_merge.dart';

/// These tests are the reason the merge rules live in a pure function: the
/// interesting cases (stale remote resurrecting a deleted list, two devices
/// editing the same item) are hard to stage against a real database and trivial
/// to state here.
void main() {
  final t0 = DateTime(2026, 8, 1, 9);
  final t1 = DateTime(2026, 8, 1, 10);
  final t2 = DateTime(2026, 8, 1, 11);

  int? noCatalog(String slug) => null;

  GroceryItemModel localItem({
    String id = 'item-1',
    String name = 'Milk',
    bool isChecked = false,
    int? canonicalItemId,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      GroceryItemModel()
        ..id = id
        ..name = name
        ..quantity = 1
        ..unit = ItemUnitDb.piece
        ..canonicalItemId = canonicalItemId
        ..isChecked = isChecked
        ..updatedAt = updatedAt ?? t1
        ..deletedAt = deletedAt;

  GroceryListModel localList({
    String name = 'Weekly',
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<GroceryItemModel> items = const [],
  }) =>
      GroceryListModel()
        ..isarId = 7
        ..publicId = 'list-1'
        ..name = name
        ..frequency = ScheduleFrequencyDb.weekly
        ..scheduledFor = t0
        ..createdAt = t0
        ..updatedAt = updatedAt
        ..deletedAt = deletedAt
        ..items = items;

  RemoteList remoteList({
    String name = 'Weekly (remote)',
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<RemoteListItem> items = const [],
  }) =>
      RemoteList(
        id: 'list-1',
        ownerId: 'user-a',
        name: name,
        frequency: ScheduleFrequencyDb.monthly.index,
        scheduledFor: t2,
        lastMissedOn: null,
        createdAt: t0,
        updatedAt: updatedAt ?? t2,
        deletedAt: deletedAt,
        items: items,
      );

  RemoteListItem remoteItem({
    String id = 'item-1',
    String name = 'Milk',
    bool isChecked = false,
    String? canonicalSlug,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) =>
      RemoteListItem(
        id: id,
        listId: 'list-1',
        name: name,
        quantity: 1,
        unit: ItemUnitDb.piece.index,
        customUnit: null,
        canonicalSlug: canonicalSlug,
        isChecked: isChecked,
        updatedAt: updatedAt ?? t2,
        deletedAt: deletedAt,
      );

  group('mergeList', () {
    test('inserts a list this device has never seen', () {
      final result = mergeList(
        local: null,
        remote: remoteList(items: [remoteItem()]),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.publicId, 'list-1');
      expect(result.list.name, 'Weekly (remote)');
      expect(result.list.ownerId, 'user-a');
      expect(result.list.items, hasLength(1));
      expect(result.overwrites, 0);
    });

    test('newer remote replaces local scalars and counts an overwrite', () {
      final result = mergeList(
        local: localList(updatedAt: t1),
        remote: remoteList(updatedAt: t2),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.name, 'Weekly (remote)');
      expect(result.list.frequency, ScheduleFrequencyDb.monthly);
      expect(result.list.scheduledFor, t2);
      expect(result.overwrites, 1);
      // The local row is updated in place, never duplicated.
      expect(result.list.isarId, 7);
    });

    test('newer local edit is kept', () {
      final result = mergeList(
        local: localList(name: 'Weekly (local)', updatedAt: t2),
        remote: remoteList(updatedAt: t1),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.name, 'Weekly (local)');
      expect(result.list.frequency, ScheduleFrequencyDb.weekly);
      expect(result.overwrites, 0);
    });

    test('a local delete is not resurrected by a stale remote row', () {
      final result = mergeList(
        local: localList(updatedAt: t2, deletedAt: t2),
        remote: remoteList(updatedAt: t1),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.deletedAt, t2);
    });

    test('a remote delete propagates when it is the newer write', () {
      final result = mergeList(
        local: localList(updatedAt: t1),
        remote: remoteList(updatedAt: t2, deletedAt: t2),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.deletedAt, t2);
    });

    test('a local tombstone sticks even when a newer live remote wins scalars', () {
      final result = mergeList(
        local: localList(updatedAt: t1, deletedAt: t1),
        remote: remoteList(name: 'Resurrected', updatedAt: t2),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.name, 'Resurrected');
      expect(result.list.deletedAt, t1);
    });

    test('a remote tombstone sticks even when a newer local edit wins scalars', () {
      final result = mergeList(
        local: localList(name: 'Renamed locally', updatedAt: t2),
        remote: remoteList(updatedAt: t1, deletedAt: t1),
        canonicalIdForSlug: noCatalog,
      );

      expect(result.list.name, 'Renamed locally');
      expect(result.list.deletedAt, t1);
    });
  });

  group('mergeItems', () {
    test('newer remote item wins, older one loses', () {
      final result = mergeItems(
        local: [
          localItem(id: 'a', isChecked: false, updatedAt: t1),
          localItem(id: 'b', name: 'Eggs', updatedAt: t2),
        ],
        remote: [
          remoteItem(id: 'a', isChecked: true, updatedAt: t2),
          remoteItem(id: 'b', name: 'Eggs (remote)', updatedAt: t1),
        ],
        canonicalIdForSlug: noCatalog,
      );

      final byId = {for (final i in result.items) i.id: i};
      expect(byId['a']!.isChecked, isTrue);
      expect(byId['b']!.name, 'Eggs');
      expect(result.overwrites, 1);
    });

    test('local-only items survive so they can be pushed', () {
      final result = mergeItems(
        local: [localItem(id: 'local-only')],
        remote: const [],
        canonicalIdForSlug: noCatalog,
      );

      expect(result.items.single.id, 'local-only');
    });

    test('remote tombstone is stored for a known item', () {
      final result = mergeItems(
        local: [localItem(id: 'a', updatedAt: t1)],
        remote: [remoteItem(id: 'a', updatedAt: t2, deletedAt: t2)],
        canonicalIdForSlug: noCatalog,
      );

      expect(result.items.single.deletedAt, t2);
    });

    test('remote tombstone for an unknown item is not stored at all', () {
      final result = mergeItems(
        local: const [],
        remote: [remoteItem(id: 'ghost', deletedAt: t2)],
        canonicalIdForSlug: noCatalog,
      );

      expect(result.items, isEmpty);
    });

    test('known slug maps to this install\'s local catalog id', () {
      final result = mergeItems(
        local: const [],
        remote: [remoteItem(canonicalSlug: 'milk-whole')],
        canonicalIdForSlug: (slug) => slug == 'milk-whole' ? 42 : null,
      );

      expect(result.items.single.canonicalItemId, 42);
    });

    test('unknown slug keeps the id this device already resolved', () {
      final result = mergeItems(
        local: [localItem(id: 'a', canonicalItemId: 9, updatedAt: t1)],
        remote: [remoteItem(id: 'a', canonicalSlug: 'not-in-catalog', updatedAt: t2)],
        canonicalIdForSlug: noCatalog,
      );

      expect(result.items.single.canonicalItemId, 9);
    });
  });
}
