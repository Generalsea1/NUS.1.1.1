import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/proactive_notification_coordinator.dart';
import 'package:nus/core/proactive_notification_delivery.dart';
import 'package:nus/core/proactive_notifications.dart';
import 'package:nus/notification_service.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScheduler implements ReminderScheduler {
  final scheduled = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduled.add(id);
  }

  @override
  Future<void> cancelReminder(String id) async {
    cancelled.add(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Appointment appointment({
    required String id,
    required DateTime startsAt,
    AppointmentReminder reminder = AppointmentReminder.none,
    AppointmentStatus status = AppointmentStatus.upcoming,
  }) {
    return Appointment(
      id: id,
      title: 'Test appointment $id',
      type: AppointmentType.personal,
      startsAt: startsAt,
      status: status,
      reminder: reminder,
    );
  }

  test('syncAppointments creates a 30-minute lead signal only when no explicit reminder exists', () async {
    SharedPreferences.setMockInitialValues({});
    final scheduler = _FakeScheduler();
    final coordinator = NusProactiveNotificationCoordinator(
      scheduler: scheduler,
      delivery: NusProactiveNotificationDelivery(
        scheduler: scheduler,
        preferences: await SharedPreferences.getInstance(),
      ),
      preferences: await SharedPreferences.getInstance(),
    );
    final now = DateTime(2026, 9, 9, 10);

    await coordinator.syncAppointments(
      now: now,
      appointments: [
        appointment(id: 'lead', startsAt: now.add(const Duration(hours: 1))),
        appointment(
          id: 'explicit',
          startsAt: now.add(const Duration(hours: 2)),
          reminder: AppointmentReminder.fifteenMinutesBefore,
        ),
      ],
    );

    expect(scheduler.scheduled, ['proactive:appointment-lead:lead']);
  });

  test('disabled proactive reminders clear previously managed notifications', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scheduler = _FakeScheduler();
    final delivery = NusProactiveNotificationDelivery(
      scheduler: scheduler,
      preferences: prefs,
    );
    final coordinator = NusProactiveNotificationCoordinator(
      scheduler: scheduler,
      delivery: delivery,
      preferences: prefs,
    );
    final now = DateTime(2026, 9, 9, 10);
    final item = appointment(id: 'one', startsAt: now.add(const Duration(hours: 1)));

    await coordinator.syncAppointments(now: now, appointments: [item]);
    await coordinator.setEnabled(enabled: false, now: now, appointments: [item]);

    expect(scheduler.cancelled, contains('proactive:appointment-lead:one'));
    expect(await coordinator.isEnabled(), isFalse);
  });
}
