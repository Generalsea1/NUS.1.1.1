import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/app_identity.dart';
import 'core/supabase_service.dart';

abstract interface class ReminderScheduler {
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  });

  Future<void> cancelReminder(String id);
}

class NotificationService implements ReminderScheduler {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(timezoneInfo.identifier);
      tz.setLocalLocation(location);
    } catch (error) {
      // Notification/timezone infrastructure must never prevent the app from
      // reaching its first usable screen. The tz package already has a
      // default location, so continue with it when device lookup fails.
      debugPrint('NUS timezone initialization failed: $error');
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    try {
      await _plugin.initialize(settings);
    } catch (error) {
      debugPrint('NUS notification plugin initialization failed: $error');
    }

    _initialized = true;
    await SupabaseService.initialize();
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    } catch (error) {
      debugPrint('NUS notification permission request failed: $error');
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final granted = await android?.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (error) {
      debugPrint('NUS exact alarm permission request failed: $error');
      return false;
    }
  }

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    await initialize();
    if (!dateTime.isAfter(DateTime.now())) return;

    final notificationId = _notificationId(id);
    final scheduled = tz.TZDateTime.from(dateTime, tz.local);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        AppIdentity.scheduleChannelId,
        AppIdentity.scheduleChannelName,
        channelDescription: AppIdentity.scheduleChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        notificationId,
        AppIdentity.reminderTitle,
        title,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: id,
      );
    } on PlatformException {
      try {
        await _plugin.zonedSchedule(
          notificationId,
          AppIdentity.reminderTitle,
          title,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: id,
        );
      } catch (error) {
        debugPrint('NUS reminder scheduling failed: $error');
      }
    } catch (error) {
      debugPrint('NUS reminder scheduling failed: $error');
    }
  }

  @override
  Future<void> cancelReminder(String id) async {
    await initialize();
    try {
      await _plugin.cancel(_notificationId(id));
    } catch (error) {
      debugPrint('NUS reminder cancellation failed: $error');
    }
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    await initialize();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (error) {
      debugPrint('NUS pending notifications lookup failed: $error');
      return const [];
    }
  }

  int _notificationId(String id) {
    final parsed = int.tryParse(id);
    if (parsed != null) {
      return parsed.remainder(2147483647).abs();
    }
    return id.hashCode.abs() % 2147483647;
  }
}
