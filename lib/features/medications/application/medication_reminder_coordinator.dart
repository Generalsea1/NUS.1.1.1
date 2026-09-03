import '../domain/medication.dart';
import '../domain/medication_reminder_port.dart';

class MedicationReminderCoordinator {
  MedicationReminderCoordinator(
    this.port, {
    DateTime Function()? clock,
    this.horizon = const Duration(days: 30),
  }) : _clock = clock ?? DateTime.now;

  final MedicationReminderPort port;
  final DateTime Function() _clock;
  final Duration horizon;

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

  static Iterable<({MedicationSchedule schedule, DateTime dateTime})> occurrences(
    Medication medication, {
    required DateTime now,
    Duration horizon = const Duration(days: 30),
    bool includePastOccurrences = false,
    bool includeNoReminderSchedules = false,
  }) sync* {
    if (medication.endDate != null && medication.endDate!.isBefore(medication.startDate)) return;

    final windowStart = _dateOnly(now);
    final horizonEnd = now.add(horizon);
    var date = medication.startDate.isAfter(windowStart) ? medication.startDate : windowStart;

    while (!date.isAfter(horizonEnd)) {
      if (medication.endDate != null && date.isAfter(medication.endDate!)) break;

      for (final schedule in medication.schedules) {
        if ((!includeNoReminderSchedules && schedule.reminder == MedicationReminder.none) ||
            !_appliesOn(schedule, date)) {
          continue;
        }
        final occurrence = date.add(Duration(minutes: schedule.minutesSinceMidnight));
        if (occurrence.isAfter(horizonEnd)) continue;
        if (!includePastOccurrences && !occurrence.isAfter(now)) continue;
        yield (schedule: schedule, dateTime: occurrence);
      }

      date = date.add(const Duration(days: 1));
    }
  }

  static bool _appliesOn(MedicationSchedule schedule, DateTime date) {
    switch (schedule.frequency) {
      case MedicationFrequency.daily:
        return true;
      case MedicationFrequency.selectedWeekdays:
        return schedule.selectedWeekdays.contains(date.weekday);
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
