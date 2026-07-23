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

  const GroceryList({
    required this.id,
    required this.name,
    required this.frequency,
    required this.scheduledFor,
    required this.createdAt,
    required this.items,
  });

  int get completedCount => items.where((i) => i.isChecked).length;
  bool get isComplete => items.isNotEmpty && completedCount == items.length;

  GroceryList copyWith({
    String? name,
    ScheduleFrequency? frequency,
    DateTime? scheduledFor,
    List<GroceryItem>? items,
  }) {
    return GroceryList(
      id: id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [id, name, frequency, scheduledFor, createdAt, items];
}
