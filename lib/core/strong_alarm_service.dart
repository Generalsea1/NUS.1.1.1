import 'package:alarm/alarm.dart';

/// High-attention reminders for appointments and scheduled calls.
///
/// This intentionally lives beside the existing local notification service so
/// ordinary medication/task notifications keep their accepted behavior.
class StrongAlarmService {
  StrongAlarmService();

  static bool _initialized = false;
  static Future<void>? _initializing;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final pending = _initializing;
    if (pending != null) {
      await pending;
      return;
    }

    final future = Alarm.init();
    _initializing = future;
    try {
      await future;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
    String? body,
  }) async {
    await _ensureInitialized();
    if (!dateTime.isAfter(DateTime.now())) return;

    final alarmId = _alarmId(id);
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: dateTime,
        assetAudioPath: null,
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
        androidSnoozeDuration: const Duration(minutes: 9),
        notificationSettings: NotificationSettings(
          title: 'NUS — تنبيه مهم',
          body: body ?? title,
          stopButton: 'إيقاف التنبيه',
          androidSnoozeButton: 'غفوة 9 دقائق',
          androidStopAlarmOnDismiss: false,
        ),
      ),
    );
  }

  Future<void> cancel(String id) async {
    await _ensureInitialized();
    await Alarm.stop(_alarmId(id));
  }

  static int _alarmId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
