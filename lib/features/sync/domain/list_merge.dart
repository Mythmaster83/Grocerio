import '../../lists/data/models/grocery_item_model.dart';
import '../../lists/data/models/grocery_list_model.dart';
import '../data/dto/remote_list.dart';

/// Pure last-write-wins merge, kept out of the sync service so the rules can be
/// tested without a database or a network.
///
/// LWW is chosen over per-field merging or CRDTs because the conflict that
/// actually happens in a grocery app is two people checking off items on the
/// same trip, and item rows are independent — so resolving per row already
/// avoids most real collisions. The residual loss is one person's rename losing
/// to another's, which is cheap to redo and expensive to engineer away.
class ListMergeResult {
  final GroceryListModel list;

  /// Local rows the remote copy replaced. Not necessarily true conflicts (a
  /// row edited only remotely counts too), which is why the sync layer logs
  /// them rather than surfacing them as errors.
  final int overwrites;

  const ListMergeResult(this.list, this.overwrites);
}

DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

bool _remoteWins(DateTime? local, DateTime remote) =>
    remote.isAfter(local ?? _epoch);

/// Merges [remote] into [local]. Pass `local: null` for a list this device has
/// never seen. [canonicalIdForSlug] maps a shared catalog slug to this install's
/// local id, returning null when the slug isn't in the local catalog.
ListMergeResult mergeList({
  required GroceryListModel? local,
  required RemoteList remote,
  required int? Function(String slug) canonicalIdForSlug,
}) {
  var overwrites = 0;

  final merged = GroceryListModel()..publicId = remote.id;
  if (local != null) merged.isarId = local.isarId;

  final takeRemoteScalars = local == null || _remoteWins(local.updatedAt, remote.updatedAt);
  if (takeRemoteScalars && local != null && local.updatedAt != remote.updatedAt) {
    overwrites++;
  }

  if (takeRemoteScalars) {
    merged
      ..name = remote.name
      ..frequency = _frequencyFromIndex(remote.frequency)
      ..scheduledFor = remote.scheduledFor
      ..lastMissedOn = remote.lastMissedOn
      ..updatedAt = remote.updatedAt
      // Deletes are sticky: a live remote row must not clear a local tombstone
      // (e.g. this device deleted, then pulled a stale live copy).
      ..deletedAt = remote.deletedAt ?? local?.deletedAt;
  } else {
    merged
      ..name = local.name
      ..frequency = local.frequency
      ..scheduledFor = local.scheduledFor
      ..lastMissedOn = local.lastMissedOn
      ..updatedAt = local.updatedAt
      // A local delete must survive a stale remote row, otherwise deleting on
      // this device silently resurrects the list on the next pull.
      ..deletedAt = local.deletedAt ?? remote.deletedAt;
  }

  merged
    ..createdAt = local?.createdAt ?? remote.createdAt
    ..ownerId = remote.ownerId;

  final itemMerge = mergeItems(
    local: local?.items ?? const [],
    remote: remote.items,
    canonicalIdForSlug: canonicalIdForSlug,
  );
  merged.items = itemMerge.items;

  return ListMergeResult(merged, overwrites + itemMerge.overwrites);
}

class ItemMergeResult {
  final List<GroceryItemModel> items;
  final int overwrites;

  const ItemMergeResult(this.items, this.overwrites);
}

/// Merges item rows by id. Local-only items are kept untouched so the next push
/// can upload them; remote-only items are added unless they arrive already
/// tombstoned, in which case there is nothing worth storing.
ItemMergeResult mergeItems({
  required List<GroceryItemModel> local,
  required List<RemoteListItem> remote,
  required int? Function(String slug) canonicalIdForSlug,
}) {
  var overwrites = 0;
  final byId = {for (final item in local) item.id: item};
  final result = <GroceryItemModel>[];
  final handled = <String>{};

  for (final remoteItem in remote) {
    handled.add(remoteItem.id);
    final localItem = byId[remoteItem.id];

    if (localItem == null) {
      if (remoteItem.deletedAt != null) continue;
      result.add(_fromRemote(remoteItem, canonicalIdForSlug));
      continue;
    }

    if (_remoteWins(localItem.updatedAt, remoteItem.updatedAt)) {
      if (localItem.updatedAt != remoteItem.updatedAt) overwrites++;
      result.add(_fromRemote(remoteItem, canonicalIdForSlug, existing: localItem));
    } else {
      // Local scalars win, but a remote tombstone still sticks.
      if (remoteItem.deletedAt != null && localItem.deletedAt == null) {
        localItem.deletedAt = remoteItem.deletedAt;
      }
      result.add(localItem);
    }
  }

  for (final item in local) {
    if (!handled.contains(item.id)) result.add(item);
  }

  return ItemMergeResult(result, overwrites);
}

GroceryItemModel _fromRemote(
  RemoteListItem remote,
  int? Function(String slug) canonicalIdForSlug, {
  GroceryItemModel? existing,
}) {
  final slug = remote.canonicalSlug;
  return GroceryItemModel()
    ..id = remote.id
    ..name = remote.name
    ..quantity = remote.quantity
    ..unit = _unitFromIndex(remote.unit)
    ..customUnit = remote.customUnit
    // An unknown slug keeps whatever this device had resolved: dropping to null
    // would lose the price link just because the catalogs differ by a version.
    ..canonicalItemId =
        (slug == null ? null : canonicalIdForSlug(slug)) ?? existing?.canonicalItemId
    ..isChecked = remote.isChecked
    ..updatedAt = remote.updatedAt
    // Same sticky-delete rule as lists: never resurrect from a live remote.
    ..deletedAt = remote.deletedAt ?? existing?.deletedAt;
}

/// Unknown indexes come from a newer client; fall back rather than crash.
ScheduleFrequencyDb _frequencyFromIndex(int index) =>
    index >= 0 && index < ScheduleFrequencyDb.values.length
        ? ScheduleFrequencyDb.values[index]
        : ScheduleFrequencyDb.oneTime;

ItemUnitDb _unitFromIndex(int index) =>
    index >= 0 && index < ItemUnitDb.values.length
        ? ItemUnitDb.values[index]
        : ItemUnitDb.piece;
