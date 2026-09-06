import 'package:flutter_test/flutter_test.dart';

import '../lib/features/appointments/application/central_recurrence_engine.dart';
import '../lib/features/appointments/domain/appointment.dart';

void main() {
  const engine = CentralRecurrenceEngine();
  final now = DateTime(2026, 9, 6, 10);

  test('returns one future occurrence for non-recurring appointment', () {
    final start = now.add(const Duration(hours: 2));

    expect(
      engine.futureOccurrences(
        startsAt: start,
        recurrence: AppointmentRecurrence.none,
        now: now,
      ),
      [start],
    );
  });

  test('daily recurrence skips past occurrences and returns twelve future occurrences', () {
    final start = now.subtract(const Duration(days: 2));

    final occurrences = engine.futureOccurrences(
      startsAt: start,
      recurrence: AppointmentRecurrence.daily,
      now: now,
    );

    expect(occurrences.length, 12);
    expect(occurrences.first, DateTime(2026, 9, 7, 10));
    expect(occurrences.last, DateTime(2026, 9, 18, 10));
  });

  test('weekly recurrence advances by seven days', () {
    final start = now.add(const Duration(hours: 1));

    final occurrences = engine.futureOccurrences(
      startsAt: start,
      recurrence: AppointmentRecurrence.weekly,
      now: now,
    );

    expect(occurrences.length, 12);
    expect(occurrences[1], start.add(const Duration(days: 7)));
    expect(occurrences[11], start.add(const Duration(days: 77)));
  });

  test('reminder offsets match the existing appointment reminder contract', () {
    expect(engine.reminderOffset(AppointmentReminder.atTime), Duration.zero);
    expect(engine.reminderOffset(AppointmentReminder.fiveMinutesBefore), const Duration(minutes: 5));
    expect(engine.reminderOffset(AppointmentReminder.fifteenMinutesBefore), const Duration(minutes: 15));
    expect(engine.reminderOffset(AppointmentReminder.thirtyMinutesBefore), const Duration(minutes: 30));
    expect(engine.reminderOffset(AppointmentReminder.oneHourBefore), const Duration(hours: 1));
    expect(engine.reminderOffset(AppointmentReminder.oneDayBefore), const Duration(days: 1));
  });
}
