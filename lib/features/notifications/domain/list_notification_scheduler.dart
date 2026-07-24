import '../../lists/domain/entities/grocery_list.dart';
import '../data/local_notifications_service.dart';

/// Schedules / cancels list reminders via [LocalNotificationsService].
class ListNotificationScheduler {
  final LocalNotificationsService _service;
  ListNotificationScheduler(this._service);

  Future<void> scheduleForList(GroceryList list) =>
      _service.scheduleShoppingDay(
        listId: list.id,
        listName: list.name,
        scheduledFor: list.scheduledFor,
      );

  Future<void> cancelForList(String listId) => _service.cancelReminder(listId);

  Future<void> notifyMissed(GroceryList list) => _service.showMissedDate(
        listId: list.id,
        listName: list.name,
      );
}
