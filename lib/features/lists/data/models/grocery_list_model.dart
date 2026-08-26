import 'package:isar_community/isar.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../../domain/entities/grocery_list.dart';
import 'grocery_item_model.dart';

part 'grocery_list_model.g.dart';

@collection
class GroceryListModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String publicId; // UUID exposed to domain/UI; isarId stays internal.

  late String name;

  @enumerated
  late ScheduleFrequencyDb frequency;

  late DateTime scheduledFor;
  late DateTime createdAt;

  /// Nullable: absent on older rows / lists that have never been overdue.
  DateTime? lastMissedOn;

  // --- Sync scaffolding (used from the Supabase phase onward) ---

  /// Last local mutation. Drives last-write-wins when the same list is edited
  /// on two devices.
  DateTime? updatedAt;

  /// Tombstone. Deletes must be recorded rather than removed, or a delete on
  /// one device is simply re-pushed by another.
  DateTime? deletedAt;

  /// Account that owns the list. Null while the app is account-less.
  String? ownerId;

  List<GroceryItemModel> items = [];

  GroceryList toDomain() => GroceryList(
        id: publicId,
        name: name,
        frequency: frequency.toDomain(),
        scheduledFor: scheduledFor,
        createdAt: createdAt,
        lastMissedOn: lastMissedOn,
        // Tombstoned items stay in storage so the deletion can reach other
        // devices, but they must never surface in the UI. Filtering here rather
        // than in each query is what makes that impossible to forget.
        items: items
            .where((i) => i.deletedAt == null)
            .map((i) => i.toDomain())
            .toList(growable: false),
      );
}

enum ScheduleFrequencyDb { oneTime, weekly, biweekly, monthly }

extension ScheduleFrequencyDbX on ScheduleFrequencyDb {
  ScheduleFrequency toDomain() => ScheduleFrequency.values[index];
  static ScheduleFrequencyDb fromDomain(ScheduleFrequency f) =>
      ScheduleFrequencyDb.values[f.index];
}
