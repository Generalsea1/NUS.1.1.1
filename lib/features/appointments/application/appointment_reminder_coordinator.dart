import '../domain/appointment.dart';
import '../domain/appointment_reminder_port.dart';
import '../../../core/recurrence/recurrence_engine.dart';
import '../../../core/recurrence/recurrence_rule.dart';

class AppointmentReminderCoordinator {
  AppointmentReminderCoordinator(
    this.port, {
    RecurrenceEngine recurrenceEngine = const RecurrenceEngine(),
  }) : _recurrenceEngine = recurrenceEngine;

  final AppointmentReminderPort port;
  final RecurrenceEngine _recurrenceEngine;
  static const _maxOccurrences = 12;

  Future<void> sync(Appointment appointment) async {
    await cancel(appointment.id);
    if (appointment.status != AppointmentStatus.upcoming ||
        appointment.reminder == AppointmentReminder.none) {
      return;
    }

    final now = DateTime.now();
    final occurrences = _futureOccurrences(appointment, now);
    final offset = _reminderOffset(appointment.reminder);

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

  List<DateTime> _futureOccurrences(Appointment appointment, DateTime now) {
    if (appointment.recurrence == AppointmentRecurrence.none) {
      return appointment.startsAt.isAfter(now) ? [appointment.startsAt] : const [];
    }

    final rule = switch (appointment.recurrence) {
      AppointmentRecurrence.daily => const RecurrenceRule.daily(),
      AppointmentRecurrence.weekly => const RecurrenceRule.weekly(),
      AppointmentRecurrence.none => const RecurrenceRule.daily(),
    };

    final step = appointment.recurrence == AppointmentRecurrence.weekly
        ? const Duration(days: 7)
        : const Duration(days: 1);
    final anchor = appointment.startsAt.isAfter(now) ? appointment.startsAt : now;
    final windowEnd = anchor.add(step * _maxOccurrences);

    return _recurrenceEngine
        .occurrences(
          start: appointment.startsAt,
          rule: rule,
          windowStart: now,
          windowEnd: windowEnd,
          maxOccurrences: _maxOccurrences,
        )
        .toList();
  }

  Duration _reminderOffset(AppointmentReminder reminder) =>
      switch (reminder) {
        AppointmentReminder.none || AppointmentReminder.atTime => Duration.zero,
        AppointmentReminder.fiveMinutesBefore => const Duration(minutes: 5),
        AppointmentReminder.fifteenMinutesBefore => const Duration(minutes: 15),
        AppointmentReminder.thirtyMinutesBefore => const Duration(minutes: 30),
        AppointmentReminder.oneHourBefore => const Duration(hours: 1),
        AppointmentReminder.oneDayBefore => const Duration(days: 1),
      };

  // Numeric IDs keep scheduling/cancellation deterministic across app restarts
  // because the existing NotificationService treats numeric IDs as-is.
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
