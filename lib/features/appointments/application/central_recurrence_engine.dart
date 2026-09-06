import '../domain/appointment.dart';

/// Central source of truth for appointment recurrence calculations.
///
/// This engine is deliberately side-effect free. Notification scheduling,
/// cancellation, and other reminder concerns remain outside the engine.
class CentralRecurrenceEngine {
  const CentralRecurrenceEngine({this.maxOccurrences = 12});

  final int maxOccurrences;

  List<DateTime> futureOccurrences({
    required DateTime startsAt,
    required AppointmentRecurrence recurrence,
    required DateTime now,
  }) {
    if (maxOccurrences <= 0) return const [];

    final occurrences = <DateTime>[];
    var occurrence = startsAt;

    while (occurrences.length < maxOccurrences) {
      if (occurrence.isAfter(now)) {
        occurrences.add(occurrence);
      }

      if (recurrence == AppointmentRecurrence.none) break;
      occurrence = nextOccurrence(occurrence, recurrence);
    }

    return occurrences;
  }

  DateTime nextOccurrence(DateTime value, AppointmentRecurrence recurrence) {
    switch (recurrence) {
      case AppointmentRecurrence.none:
        return value;
      case AppointmentRecurrence.daily:
        return value.add(const Duration(days: 1));
      case AppointmentRecurrence.weekly:
        return value.add(const Duration(days: 7));
    }
  }

  Duration reminderOffset(AppointmentReminder reminder) {
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
}
