import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

  static const _channelId = 'nus_schedule';
  static const _channelName = 'NUS reminders';
  static const _channelDescription = 'Notifications for scheduled NUS reminders.';

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestExactAlarmsPermission();
    return granted ?? true;
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
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    try {
      await _plugin.zonedSchedule(
        notificationId,
        'NUS Reminder',
        title,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: id,
      );
    } on PlatformException {
      await _plugin.zonedSchedule(
        notificationId,
        'NUS Reminder',
        title,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: id,
      );
    }
  }

  @override
  Future<void> cancelReminder(String id) async {
    await initialize();
    await _plugin.cancel(_notificationId(id));
  }

  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    await initialize();
    return _plugin.pendingNotificationRequests();
  }

  int _notificationId(String id) {
    final parsed = int.tryParse(id);
    if (parsed != null) {
      return parsed.remainder(2147483647).abs();
    }
    return id.hashCode.abs() % 2147483647;
  }
}
