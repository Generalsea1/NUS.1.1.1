import '../domain/appointment.dart';
import '../domain/appointment_reminder_port.dart';
import 'central_recurrence_engine.dart';

class AppointmentReminderCoordinator {
  AppointmentReminderCoordinator(
    this.port, {
    CentralRecurrenceEngine recurrenceEngine = const CentralRecurrenceEngine(),
  }) : _recurrenceEngine = recurrenceEngine;

  final AppointmentReminderPort port;
  final CentralRecurrenceEngine _recurrenceEngine;
  static const _maxOccurrences = 12;

  Future<void> sync(Appointment appointment) async {
    await cancel(appointment.id);
    if (appointment.status != AppointmentStatus.upcoming ||
        appointment.reminder == AppointmentReminder.none) {
      return;
    }

    final now = DateTime.now();
    final occurrences = _recurrenceEngine.futureOccurrences(
      startsAt: appointment.startsAt,
      recurrence: appointment.recurrence,
      now: now,
    );
    final offset = _recurrenceEngine.reminderOffset(appointment.reminder);

    for (var index = 0; index < occurrences.length; index++) {
      final occurrence = occurrences[index];
      final reminderAt = occurrence.subtract(offset);
      if (reminderAt.isAfter(now) || appointment.reminder == AppointmentReminder.atTime) {
        await port.schedule(
          id: _occurrenceId(appointment.id, index),
          title: appointment.title,
          dateTime: reminderAt.isAfter(now) ? reminderAt : occurrence,
        );
      }
    }

    final followUp = appointment.followUpAt;
    if (appointment.isDoctor && followUp != null && followUp.isAfter(now)) {
      await port.schedule(
        id: _followUpId(appointment.id),
        title: 'Follow-up: ${appointment.title}',
        dateTime: followUp,
      );
    }
  }

  Future<void> cancel(String appointmentId) async {
    for (var index = 0; index < _maxOccurrences; index++) {
      await port.cancel(_occurrenceId(appointmentId, index));
    }
    await port.cancel(_followUpId(appointmentId));
  }

  Future<void> rescheduleAll(Iterable<Appointment> appointments) async {
    for (final appointment in appointments) {
      await sync(appointment);
    }
  }

  static String _occurrenceId(String appointmentId, int index) =>
      _stableId('$appointmentId:occurrence:$index').toString();

  static String _followUpId(String appointmentId) =>
      _stableId('$appointmentId:followup').toString();

  static int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
