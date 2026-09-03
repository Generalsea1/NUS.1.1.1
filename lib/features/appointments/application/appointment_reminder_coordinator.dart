import '../domain/appointment.dart';
import '../domain/appointment_reminder_port.dart';

class AppointmentReminderCoordinator {
  AppointmentReminderCoordinator(this.port);

  final AppointmentReminderPort port;
  static const _maxOccurrences = 12;

  Future<void> sync(Appointment appointment) async {
    await cancel(appointment.id);
    if (appointment.status != AppointmentStatus.upcoming ||
        appointment.reminder == AppointmentReminder.none) {
      return;
    }

    var occurrence = appointment.startsAt;
    var scheduledCount = 0;
    final now = DateTime.now();
    while (scheduledCount < _maxOccurrences) {
      if (occurrence.isAfter(now)) {
        final reminderAt = occurrence.subtract(_reminderOffset(appointment.reminder));
        if (reminderAt.isAfter(now)) {
          await port.schedule(
            id: _occurrenceId(appointment.id, scheduledCount),
            title: appointment.title,
            dateTime: reminderAt,
          );
        }
        scheduledCount++;
      }

      if (appointment.recurrence == AppointmentRecurrence.none) break;
      occurrence = _nextOccurrence(occurrence, appointment.recurrence);
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

  static Duration _reminderOffset(AppointmentReminder reminder) {
    switch (reminder) {
      case AppointmentReminder.none:
      case AppointmentReminder.atTime:
        return Duration.zero;
      case AppointmentReminder.fiveMinutesBefore:
        return const Duration(minutes: 5);
      case AppointmentReminder.fifteenMinutesBefore:
        return const Duration(minutes: 15);
      case AppointmentReminder.thirtyMinutesBefore:
        return const Duration(minutes: 30);
      case AppointmentReminder.oneHourBefore:
        return const Duration(hours: 1);
      case AppointmentReminder.oneDayBefore:
        return const Duration(days: 1);
    }
  }

  static DateTime _nextOccurrence(DateTime value, AppointmentRecurrence recurrence) {
    switch (recurrence) {
      case AppointmentRecurrence.none:
        return value;
      case AppointmentRecurrence.daily:
        return value.add(const Duration(days: 1));
      case AppointmentRecurrence.weekly:
        return value.add(const Duration(days: 7));
    }
  }

  static String _occurrenceId(String appointmentId, int index) =>
      'appointment:$appointmentId:occurrence:$index';

  static String _followUpId(String appointmentId) => 'appointment:$appointmentId:followup';
}
