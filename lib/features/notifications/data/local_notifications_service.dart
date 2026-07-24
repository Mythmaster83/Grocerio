import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/utils/app_logger.dart';
import '../domain/notification_ids.dart';

/// Thin wrapper around [FlutterLocalNotificationsPlugin].
/// Desktop (Windows/Linux/macOS unsupported paths) no-ops after init fails.
class LocalNotificationsService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tz_data.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e, st) {
      logger.warning('Local notifications unavailable: $e');
      logger.error('Notification init failed', e, st);
      _ready = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleShoppingDay({
    required String listId,
    required String listName,
    required DateTime scheduledFor,
  }) async {
    if (!_ready) return;
    final when = shoppingDayReminderLocal(scheduledFor);
    if (!when.isAfter(DateTime.now())) {
      return;
    }
    await requestPermissions();
    final id = notificationIdForList(listId);
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: listName,
        body: 'Shopping day',
        scheduledDate: tzWhen,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'shopping_day',
            'Shopping day reminders',
            channelDescription:
                'Reminds you on the morning of a planned list date',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e, st) {
      logger.error('Failed to schedule shopping reminder', e, st);
    }
  }

  Future<void> cancelReminder(String listId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: notificationIdForList(listId));
    } catch (e, st) {
      logger.error('Failed to cancel reminder', e, st);
    }
  }

  Future<void> showMissedDate({
    required String listId,
    required String listName,
  }) async {
    if (!_ready) return;
    await requestPermissions();
    final id = notificationIdForList('${listId}_miss') & 0x7fffffff;
    try {
      await _plugin.show(
        id: id == 0 ? 2 : id,
        title: 'Last date missed',
        body: listName,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'missed_date',
            'Missed list dates',
            channelDescription:
                'Shown when a planned list date was skipped',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e, st) {
      logger.error('Failed to show miss notification', e, st);
    }
  }
}
