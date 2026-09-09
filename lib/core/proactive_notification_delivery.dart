import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'proactive_notifications.dart';
import '../notification_service.dart';

/// Delivers planner output through NUS's existing reminder infrastructure.
///
/// Previously scheduled proactive IDs are persisted and cancelled before the
/// next plan is applied, so deleted or changed source data cannot leave stale
/// proactive reminders behind.
class NusProactiveNotificationDelivery {
  NusProactiveNotificationDelivery({
    required ReminderScheduler scheduler,
    NusProactiveNotificationPlanner planner = const NusProactiveNotificationPlanner(),
    SharedPreferences? preferences,
  })  : _scheduler = scheduler,
        _planner = planner,
        _preferences = preferences;

  static const _storageKey = 'nus.proactive_notifications.managed_ids.v1';

  final ReminderScheduler _scheduler;
  final NusProactiveNotificationPlanner _planner;
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<List<NusProactiveNotification>> sync({
    required DateTime now,
    required Iterable<NusProactiveSignal> signals,
  }) async {
    final prefs = await _prefs;
    final previousIds = _readIds(prefs.getString(_storageKey));
    for (final id in previousIds) {
      await _scheduler.cancelReminder(id);
    }

    final planned = _planner.plan(now: now, signals: signals);
    for (final notification in planned) {
      await _scheduler.scheduleReminder(
        id: notification.id,
        title: notification.title,
        dateTime: notification.scheduledAt,
      );
    }

    await prefs.setString(
      _storageKey,
      jsonEncode(planned.map((notification) => notification.id).toList()),
    );
    return planned;
  }

  List<String> _readIds(String? raw) {
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      return decoded.whereType<String>().where((id) => id.isNotEmpty).toList();
    } on Object {
      return <String>[];
    }
  }
}
