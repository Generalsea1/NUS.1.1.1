import 'package:shared_preferences/shared_preferences.dart';

import '../features/appointments/domain/appointment.dart';
import 'proactive_notification_delivery.dart';
import 'proactive_notifications.dart';
import '../notification_service.dart';

/// Owns the user-facing proactive reminder policy and appointment signal source.
/// The coordinator deliberately keeps the policy local and deterministic.
class NusProactiveNotificationCoordinator {
  NusProactiveNotificationCoordinator({
    required ReminderScheduler scheduler,
    SharedPreferences? preferences,
    NusProactiveNotificationDelivery? delivery,
  })  : _preferences = preferences,
        _delivery = delivery ?? NusProactiveNotificationDelivery(scheduler: scheduler);

  static const enabledKey = 'nus.proactive_notifications.enabled.v1';

  final SharedPreferences? _preferences;
  final NusProactiveNotificationDelivery _delivery;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  Future<bool> isEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(enabledKey) ?? true;
  }

  Future<List<NusProactiveNotification>> syncAppointments({
    required DateTime now,
    required Iterable<Appointment> appointments,
  }) async {
    final enabled = await isEnabled();
    if (!enabled) {
      return _delivery.sync(now: now, signals: const <NusProactiveSignal>[]);
    }

    final signals = appointments
        .where(
          (appointment) =>
              appointment.status == AppointmentStatus.upcoming &&
              appointment.reminder == AppointmentReminder.none,
        )
        .map((appointment) {
      final scheduledAt =
          appointment.startsAt.subtract(const Duration(minutes: 30));
      return NusProactiveSignal(
        id: 'appointment-lead:${appointment.id}',
        title: 'موعد قريب',
        body: 'عندك «${appointment.title}» بعد 30 دقيقة.',
        scheduledAt: scheduledAt,
      );
    });

    return _delivery.sync(now: now, signals: signals);
  }

  Future<void> setEnabled({
    required bool enabled,
    required DateTime now,
    required Iterable<Appointment> appointments,
  }) async {
    final prefs = await _prefs;
    await prefs.setBool(enabledKey, enabled);
    await syncAppointments(now: now, appointments: appointments);
  }
}
