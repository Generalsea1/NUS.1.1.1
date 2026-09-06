import '../../../core/recurrence/recurrence_engine.dart';
import '../../../core/recurrence/recurrence_rule.dart';
import '../domain/medication.dart';
import '../domain/medication_reminder_port.dart';

class MedicationReminderCoordinator {
  MedicationReminderCoordinator(
    this.port, {
    DateTime Function()? clock,
    this.horizon = const Duration(days: 30),
    RecurrenceEngine recurrenceEngine = const RecurrenceEngine(),
  })  : _clock = clock ?? DateTime.now,
        _recurrenceEngine = recurrenceEngine;

  final MedicationReminderPort port;
  final DateTime Function() _clock;
  final Duration horizon;
  final RecurrenceEngine _recurrenceEngine;

  Future<void> sync(Medication medication, {Medication? previous}) async {
    await cancel(previous ?? medication);
    await _scheduleIfEligible(medication);
  }

  Future<void> _scheduleIfEligible(Medication medication) async {
    if (MedicationValidator.validate(medication).isNotEmpty || !medication.isActive) return;

    final now = _clock();
    for (final item in occurrences(medication, now: now, horizon: horizon)) {
      final reminderAt = reminderDateTime(item.dateTime, item.schedule.reminder);
      if (!reminderAt.isAfter(now)) continue;
      await port.schedule(
        id: reminderId(
          medication.id,
          item.schedule.id,
          item.dateTime,
        ),
        title: medication.name,
        dateTime: reminderAt,
      );
    }
  }

  Future<void> cancel(Medication medication) async {
    final now = _clock();
    for (final item in occurrences(
      medication,
      now: now,
      horizon: horizon,
      includePastOccurrences: true,
      includeNoReminderSchedules: true,
    )) {
      await port.cancel(reminderId(medication.id, item.schedule.id, item.dateTime));
    }
  }

  Iterable<({MedicationSchedule schedule, DateTime dateTime})> occurrences(
    Medication medication, {
    required DateTime now,
    Duration horizon = const Duration(days: 30),
    bool includePastOccurrences = false,
    bool includeNoReminderSchedules = false,
  }) sync* {
    if (medication.endDate != null && medication.endDate!.isBefore(medication.startDate)) return;

    final windowStart = _dateOnly(now);
    final horizonEnd = now.add(horizon);
    var startDate = medication.startDate.isAfter(windowStart)
        ? medication.startDate
        : windowStart;

    if (medication.endDate != null && startDate.isAfter(medication.endDate!)) return;

    for (final schedule in medication.schedules) {
      if (!includeNoReminderSchedules && schedule.reminder == MedicationReminder.none) continue;

      final recurrenceRule = switch (schedule.frequency) {
        MedicationFrequency.daily => const RecurrenceRule.daily(),
        MedicationFrequency.selectedWeekdays =>
          RecurrenceRule.selectedWeekdays(schedule.selectedWeekdays.toSet()),
      };

      final scheduleStart = startDate.add(Duration(minutes: schedule.minutesSinceMidnight));
      final scheduleWindowEnd = medication.endDate == null
          ? horizonEnd
          : (() {
              final end = _dateOnly(medication.endDate!).add(const Duration(days: 1));
              return end.isBefore(horizonEnd) ? end : horizonEnd;
            })();

      for (final dateTime in _recurrenceEngine.occurrences(
        start: scheduleStart,
        rule: recurrenceRule,
        windowStart: includePastOccurrences ? scheduleStart : now,
        windowEnd: scheduleWindowEnd,
        includePastOccurrences: includePastOccurrences,
      )) {
        if (dateTime.isAfter(horizonEnd)) continue;
        yield (schedule: schedule, dateTime: dateTime);
      }
    }
  }

  static DateTime reminderDateTime(DateTime occurrence, MedicationReminder reminder) {
    switch (reminder) {
      case MedicationReminder.none:
      case MedicationReminder.atTime:
        return occurrence;
      case MedicationReminder.fiveMinutesBefore:
        return occurrence.subtract(const Duration(minutes: 5));
      case MedicationReminder.fifteenMinutesBefore:
        return occurrence.subtract(const Duration(minutes: 15));
      case MedicationReminder.thirtyMinutesBefore:
        return occurrence.subtract(const Duration(minutes: 30));
      case MedicationReminder.sixtyMinutesBefore:
        return occurrence.subtract(const Duration(hours: 1));
      case MedicationReminder.oneDayBefore:
        return occurrence.subtract(const Duration(days: 1));
    }
  }

  static String canonicalReminderKey(
    String medicationId,
    String scheduleId,
    DateTime occurrence,
  ) {
    final date = '${occurrence.year.toString().padLeft(4, '0')}-'
        '${occurrence.month.toString().padLeft(2, '0')}-'
        '${occurrence.day.toString().padLeft(2, '0')}';
    final time = '${occurrence.hour.toString().padLeft(2, '0')}-'
        '${occurrence.minute.toString().padLeft(2, '0')}';
    return 'medication:$medicationId:schedule:$scheduleId:occurrence:$date:$time';
  }

  static String reminderId(String medicationId, String scheduleId, DateTime occurrence) =>
      _stableId(canonicalReminderKey(medicationId, scheduleId, occurrence)).toString();

  static int _stableId(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);
}
