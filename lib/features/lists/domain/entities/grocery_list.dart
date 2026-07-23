import 'package:equatable/equatable.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import 'grocery_item.dart';

class GroceryList extends Equatable {
  final String id;
  final String name;
  final ScheduleFrequency frequency;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final List<GroceryItem> items;

  /// Set by schedule reconciliation when a planned date was skipped.
  /// Non-null → show the "Last date missed" indicator. Cleared on dismiss
  /// or Complete Shopping; may be re-set on the next app open if still overdue.
  final DateTime? lastMissedOn;

  const GroceryList({
    required this.id,
    required this.name,
    required this.frequency,
    required this.scheduledFor,
    required this.createdAt,
    required this.items,
    this.lastMissedOn,
  });

  int get completedCount => items.where((i) => i.isChecked).length;
  bool get isComplete => items.isNotEmpty && completedCount == items.length;

  bool get hasMissedDate => lastMissedOn != null;

  GroceryList copyWith({
    String? name,
    ScheduleFrequency? frequency,
    DateTime? scheduledFor,
    List<GroceryItem>? items,
    DateTime? lastMissedOn,
    bool clearLastMissedOn = false,
  }) {
    return GroceryList(
      id: id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt,
      items: items ?? this.items,
      lastMissedOn:
          clearLastMissedOn ? null : (lastMissedOn ?? this.lastMissedOn),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, frequency, scheduledFor, createdAt, items, lastMissedOn];
}
