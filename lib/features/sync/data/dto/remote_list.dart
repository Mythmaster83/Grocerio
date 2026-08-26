import '../../../lists/data/models/grocery_item_model.dart';
import '../../../lists/data/models/grocery_list_model.dart';

/// Wire format for the `lists` and `list_items` tables.
///
/// Deliberately separate from the Isar models: the server stores a catalog
/// *slug* where the device stores a local integer id, and hand-written mapping
/// is what keeps that translation in one visible place instead of leaking
/// install-specific ids into shared rows.
class RemoteList {
  final String id;
  final String ownerId;
  final String name;
  final int frequency;
  final DateTime scheduledFor;
  final DateTime? lastMissedOn;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<RemoteListItem> items;

  const RemoteList({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.frequency,
    required this.scheduledFor,
    required this.lastMissedOn,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.items = const [],
  });

  factory RemoteList.fromJson(
    Map<String, dynamic> json, {
    List<RemoteListItem> items = const [],
  }) {
    return RemoteList(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: (json['name'] as String?) ?? '',
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      scheduledFor: _date(json['scheduled_for']) ?? DateTime.now(),
      lastMissedOn: _date(json['last_missed_on']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      deletedAt: _date(json['deleted_at']),
      items: items,
    );
  }

  /// Items are pushed separately, so they are not part of this payload.
  ///
  /// [deleted_at] is only sent when set. A live upsert that includes
  /// `deleted_at: null` would wipe a tombstone another device already wrote,
  /// and the next pull would resurrect the list on every peer.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'frequency': frequency,
      'scheduled_for': scheduledFor.toUtc().toIso8601String(),
      'last_missed_on': lastMissedOn?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    if (deletedAt != null) {
      json['deleted_at'] = deletedAt!.toUtc().toIso8601String();
    }
    return json;
  }

  static RemoteList fromLocal(GroceryListModel model, {required String ownerId}) {
    return RemoteList(
      id: model.publicId,
      ownerId: ownerId,
      name: model.name,
      frequency: model.frequency.index,
      scheduledFor: model.scheduledFor,
      lastMissedOn: model.lastMissedOn,
      createdAt: model.createdAt,
      // A row that has never been written locally still needs an updatedAt for
      // last-write-wins; createdAt is the only honest stand-in.
      updatedAt: model.updatedAt ?? model.createdAt,
      deletedAt: model.deletedAt,
      items: [
        for (final item in model.items) RemoteListItem.fromLocal(item, model.publicId),
      ],
    );
  }
}

class RemoteListItem {
  final String id;
  final String listId;
  final String name;
  final double quantity;
  final int unit;
  final String? customUnit;
  final String? canonicalSlug;
  final bool isChecked;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const RemoteListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.customUnit,
    required this.canonicalSlug,
    required this.isChecked,
    required this.updatedAt,
    required this.deletedAt,
  });

  factory RemoteListItem.fromJson(Map<String, dynamic> json) {
    return RemoteListItem(
      id: json['id'] as String,
      listId: json['list_id'] as String,
      name: (json['name'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: (json['unit'] as num?)?.toInt() ?? 0,
      customUnit: json['custom_unit'] as String?,
      canonicalSlug: json['canonical_slug'] as String?,
      isChecked: (json['is_checked'] as bool?) ?? false,
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      deletedAt: _date(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'list_id': listId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'custom_unit': customUnit,
      'canonical_slug': canonicalSlug,
      'is_checked': isChecked,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    if (deletedAt != null) {
      json['deleted_at'] = deletedAt!.toUtc().toIso8601String();
    }
    return json;
  }

  /// [canonicalSlug] is filled in by the caller, which holds the catalog map.
  static RemoteListItem fromLocal(
    GroceryItemModel item,
    String listId, {
    String? canonicalSlug,
  }) {
    return RemoteListItem(
      id: item.id,
      listId: listId,
      name: item.name,
      quantity: item.quantity,
      // Enum index, so ItemUnitDb ordering is part of the wire contract:
      // append new units, never reorder them.
      unit: item.unit.index,
      customUnit: item.customUnit,
      canonicalSlug: canonicalSlug,
      isChecked: item.isChecked,
      updatedAt: item.updatedAt,
      deletedAt: item.deletedAt,
    );
  }

  RemoteListItem withCanonicalSlug(String? slug) => RemoteListItem(
        id: id,
        listId: listId,
        name: name,
        quantity: quantity,
        unit: unit,
        customUnit: customUnit,
        canonicalSlug: slug,
        isChecked: isChecked,
        updatedAt: updatedAt,
        deletedAt: deletedAt,
      );
}

DateTime? _date(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  return DateTime.tryParse(value.toString())?.toLocal();
}
