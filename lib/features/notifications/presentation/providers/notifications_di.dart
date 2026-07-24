import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local_notifications_service.dart';
import '../../domain/list_notification_scheduler.dart';

final localNotificationsServiceProvider =
    Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});

final listNotificationSchedulerProvider =
    Provider<ListNotificationScheduler>((ref) {
  return ListNotificationScheduler(
    ref.watch(localNotificationsServiceProvider),
  );
});
