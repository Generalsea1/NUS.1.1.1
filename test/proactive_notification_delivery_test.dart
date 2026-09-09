import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nus/core/proactive_notification_delivery.dart';
import 'package:nus/notification_service.dart';

class _FakeScheduler implements ReminderScheduler {
  final scheduled = <({String id, String title, DateTime dateTime})>[];
  final cancelled = <String>[];

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduled.add((id: id, title: title, dateTime: dateTime));
  }

  @override
  Future<void> cancelReminder(String id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sync delivers planned notifications through ReminderScheduler', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scheduler = _FakeScheduler();
    final delivery = NusProactiveNotificationDelivery(
      scheduler: scheduler,
      preferences: prefs,
    );
    final now = DateTime(2026, 9, 9, 8);

    final result = await delivery.sync(
      now: now,
      signals: [
        NusProactiveSignal(
          id: 'appointment-lead:1',
          title: 'موعد قريب',
          body: 'عندك موعد',
          scheduledAt: now.add(const Duration(minutes: 30)),
        ),
      ],
    );

    expect(result.single.id, 'proactive:appointment-lead:1');
    expect(scheduler.scheduled.map((item) => item.id), ['proactive:appointment-lead:1']);
    expect(scheduler.scheduled.single.title, 'موعد قريب');
  });

  test('sync cancels the previous managed set before applying the new plan', () async {
    SharedPreferences.setMockInitialValues({
      'nus.proactive_notifications.managed_ids.v1':
          '["proactive:old-1","proactive:old-2"]',
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = _FakeScheduler();
    final delivery = NusProactiveNotificationDelivery(
      scheduler: scheduler,
      preferences: prefs,
    );
    final now = DateTime(2026, 9, 9, 8);

    await delivery.sync(
      now: now,
      signals: [
        NusProactiveSignal(
          id: 'new',
          title: 'جديد',
          body: 'جديد',
          scheduledAt: now.add(const Duration(hours: 1)),
        ),
      ],
    );

    expect(scheduler.cancelled, ['proactive:old-1', 'proactive:old-2']);
    expect(scheduler.scheduled.map((item) => item.id), ['proactive:new']);
  });
}
