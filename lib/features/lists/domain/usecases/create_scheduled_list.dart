import '../../../../core/utils/result.dart';
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../entities/grocery_list.dart';
import '../repositories/lists_repository.dart';

/// Usecases exist for logic that is more than "call the repository
/// method with the same arguments" — i.e. there's a decision or
/// transformation involved. Pure CRUD (addItem, deleteItem, updateItem)
/// is intentionally called directly from the Riverpod notifier below;
/// adding a pass-through usecase for those would be ceremony with no
/// payoff. This one earns its place because it decides *what* scheduledFor
/// should be when the caller only supplies "today" + a frequency.
class CreateScheduledList {
  final ListsRepository _repository;
  CreateScheduledList(this._repository);

  Future<Result<GroceryList>> call({
    required String name,
    required ScheduleFrequency frequency,
    DateTime? explicitDate,
  }) {
    final scheduledFor = explicitDate ?? DateTime.now();
    return _repository.createList(
      name: name,
      scheduledFor: scheduledFor,
      frequencyIndex: frequency.index,
    );
  }
}
