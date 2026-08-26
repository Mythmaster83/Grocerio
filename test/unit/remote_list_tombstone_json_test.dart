import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/sync/data/dto/remote_list.dart';

void main() {
  final t0 = DateTime.utc(2026, 8, 1, 9);

  group('RemoteList.toJson', () {
    test('omits deleted_at when the list is live', () {
      final json = RemoteList(
        id: 'list-1',
        ownerId: 'user-a',
        name: 'Weekly',
        frequency: 1,
        scheduledFor: t0,
        lastMissedOn: null,
        createdAt: t0,
        updatedAt: t0,
        deletedAt: null,
      ).toJson();

      expect(json.containsKey('deleted_at'), isFalse);
    });

    test('includes deleted_at when the list is tombstoned', () {
      final deleted = t0.add(const Duration(hours: 1));
      final json = RemoteList(
        id: 'list-1',
        ownerId: 'user-a',
        name: 'Weekly',
        frequency: 1,
        scheduledFor: t0,
        lastMissedOn: null,
        createdAt: t0,
        updatedAt: deleted,
        deletedAt: deleted,
      ).toJson();

      expect(json['deleted_at'], deleted.toIso8601String());
    });
  });

  group('RemoteListItem.toJson', () {
    test('omits deleted_at when the item is live', () {
      final json = RemoteListItem(
        id: 'item-1',
        listId: 'list-1',
        name: 'Milk',
        quantity: 1,
        unit: 0,
        customUnit: null,
        canonicalSlug: null,
        isChecked: false,
        updatedAt: t0,
        deletedAt: null,
      ).toJson();

      expect(json.containsKey('deleted_at'), isFalse);
    });
  });
}
