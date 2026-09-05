import 'recurrence_rule.dart';

/// Calculates recurrence occurrences without owning reminders or persistence.
class RecurrenceEngine {
  const RecurrenceEngine();

  Iterable<DateTime> occurrences({
    required DateTime start,
    required RecurrenceRule rule,
    required DateTime windowStart,
    required DateTime windowEnd,
    bool includePastOccurrences = false,
  }) sync* {
    if (!windowEnd.isAfter(windowStart)) return;
    if (rule.validate().isNotEmpty) return;

    var occurrence = start;
    if (rule.isSelectedWeekdays) {
      occurrence = DateTime(
        start.year,
        start.month,
        start.day,
        start.hour,
        start.minute,
        start.second,
        start.millisecond,
        start.microsecond,
      );
    }

    while (occurrence.isBefore(windowEnd)) {
      final eligible = includePastOccurrences
          ? !occurrence.isAfter(windowEnd)
          : occurrence.isAfter(windowStart);
      if (eligible && _matches(rule, occurrence)) yield occurrence;

      occurrence = _next(occurrence, rule);
      if (occurrence == start) return;
    }
  }

  static bool _matches(RecurrenceRule rule, DateTime occurrence) {
    if (!rule.isSelectedWeekdays) return true;
    return rule.selectedWeekdays.contains(occurrence.weekday);
  }

  static DateTime _next(DateTime value, RecurrenceRule rule) {
    switch (rule.frequency) {
      case RecurrenceFrequency.daily:
        return value.add(const Duration(days: 1));
      case RecurrenceFrequency.weekly:
        return value.add(const Duration(days: 7));
      case RecurrenceFrequency.selectedWeekdays:
        return value.add(const Duration(days: 1));
    }
  }
}
