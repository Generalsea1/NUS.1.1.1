import '../../../core/recurrence/recurrence_engine.dart';
import '../../../core/recurrence/recurrence_rule.dart';
import '../domain/appointment.dart';

/// Appointment-facing adapter over the domain-neutral recurrence engine.
///
/// Owns recurrence semantics only; notifications, persistence, and UI remain
/// outside this class.
class CentralRecurrenceEngine {
  const CentralRecurrenceEngine({
    RecurrenceEngine recurrenceEngine = const RecurrenceEngine(),
  }) : _recurrenceEngine = recurrenceEngine;

  final RecurrenceEngine _recurrenceEngine;
  static const _maxOccurrences = 12;

  List<DateTime> futureOccurrences({
    required DateTime startsAt,
    required AppointmentRecurrence recurrence,
    required DateTime now,
  }) {
    if (recurrence == AppointmentRecurrence.none) {
      return startsAt.isAfter(now) ? [startsAt] : const [];
    }

    final rule = switch (recurrence) {
      AppointmentRecurrence.daily => const RecurrenceRule.daily(),
      AppointmentRecurrence.weekly => const RecurrenceRule.weekly(),
      AppointmentRecurrence.none => const RecurrenceRule.daily(),
    };

    final step = recurrence == AppointmentRecurrence.weekly
        ? const Duration(days: 7)
        : const Duration(days: 1);
    final anchor = startsAt.isAfter(now) ? startsAt : now;
    final windowEnd = anchor.add(step * _maxOccurrences);

    return _recurrenceEngine
        .occurrences(
          start: startsAt,
          rule: rule,
          windowStart: now,
          windowEnd: windowEnd,
          maxOccurrences: _maxOccurrences,
        )
        .toList();
  }

  Duration reminderOffset(AppointmentReminder reminder) =>
      switch (reminder) {
        AppointmentReminder.none || AppointmentReminder.atTime => Duration.zero,
        AppointmentReminder.fiveMinutesBefore => const Duration(minutes: 5),
        AppointmentReminder.fifteenMinutesBefore => const Duration(minutes: 15),
        AppointmentReminder.thirtyMinutesBefore => const Duration(minutes: 30),
        AppointmentReminder.oneHourBefore => const Duration(hours: 1),
        AppointmentReminder.oneDayBefore => const Duration(days: 1),
      };
}
