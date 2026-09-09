import 'proactive_notifications.dart';
import '../notification_service.dart';

/// Delivers planner output through NUS's existing reminder infrastructure.
///
/// The coordinator is intentionally small and deterministic: it does not
/// generate content, call AI, or create a second notification stack.
class NusProactiveNotificationDelivery {
  const NusProactiveNotificationDelivery({
    required ReminderScheduler scheduler,
    NusProactiveNotificationPlanner planner = const NusProactiveNotificationPlanner(),
  })  : _scheduler = scheduler,
        _planner = planner;

  final ReminderScheduler _scheduler;
  final NusProactiveNotificationPlanner _planner;

  Future<List<NusProactiveNotification>> sync({
    required DateTime now,
    required Iterable<NusProactiveSignal> signals,
  }) async {
    final planned = _planner.plan(now: now, signals: signals);
    for (final notification in planned) {
      await _scheduler.scheduleReminder(
        id: notification.id,
        title: notification.title,
        dateTime: notification.scheduledAt,
      );
    }
    return planned;
  }
}
