import 'package:isar/isar.dart';
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

  List<GroceryItemModel> items = [];

  GroceryList toDomain() => GroceryList(
        id: publicId,
        name: name,
        frequency: frequency.toDomain(),
        scheduledFor: scheduledFor,
        createdAt: createdAt,
        items: items.map((i) => i.toDomain()).toList(growable: false),
      );
}

enum ScheduleFrequencyDb { oneTime, weekly, biweekly, monthly }

extension ScheduleFrequencyDbX on ScheduleFrequencyDb {
  ScheduleFrequency toDomain() => ScheduleFrequency.values[index];
  static ScheduleFrequencyDb fromDomain(ScheduleFrequency f) =>
      ScheduleFrequencyDb.values[f.index];
}
