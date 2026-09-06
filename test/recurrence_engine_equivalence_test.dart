import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/recurrence/recurrence_engine.dart';
import 'package:nus/core/recurrence/recurrence_rule.dart';
import 'package:nus/features/appointments/application/appointment_reminder_coordinator.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/appointments/domain/appointment_reminder_port.dart';
import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/domain/medication.dart';

class _AppointmentPort implements AppointmentReminderPort {
  final scheduled = <DateTime>[];
  @override
  Future<void> schedule({required String id, required String title, required DateTime dateTime}) async {
    scheduled.add(dateTime);
  }
  @override
  Future<void> cancel(String id) async {}
}

class _MedicationPort implements MedicationReminderPort {
  @override
  Future<void> schedule({required String id, required String title, required DateTime dateTime}) async {}

  @override
  Future<void> cancel(String id) async {}
}

void main() {
  const engine = RecurrenceEngine();
  final now = DateTime(2026, 9, 6, 8);

  test('daily and weekly recurrence match existing Appointment coordinator semantics', () async {
    for (final recurrence in [AppointmentRecurrence.daily, AppointmentRecurrence.weekly]) {
      final port = _AppointmentPort();
      final appointment = Appointment(
        id: 'equivalence-$recurrence',
        title: 'Equivalence',
        startsAt: DateTime(2026, 9, 6, 9),
        recurrence: recurrence,
        reminder: AppointmentReminder.atTime,
      );
      final coordinator = AppointmentReminderCoordinator(port);
      await coordinator.sync(appointment);

      final rule = recurrence == AppointmentRecurrence.daily
          ? const RecurrenceRule.daily()
          : const RecurrenceRule.weekly();
      final expected = engine
          .occurrences(
            start: appointment.startsAt,
            rule: rule,
            windowStart: now,
            windowEnd: now.add(const Duration(days: 90)),
          )
          .take(12)
          .toList();

      expect(port.scheduled, expected);
    }
  });

  test('daily and selected-weekday recurrence match existing Medication coordinator semantics', () {
    final cases = <MedicationSchedule>[
      MedicationSchedule(
        id: 'daily',
        minutesSinceMidnight: 9 * 60,
        frequency: MedicationFrequency.daily,
        reminder: MedicationReminder.atTime,
      ),
      MedicationSchedule(
        id: 'weekdays',
        minutesSinceMidnight: 9 * 60,
        frequency: MedicationFrequency.selectedWeekdays,
        selectedWeekdays: const [1, 3, 5],
        reminder: MedicationReminder.atTime,
      ),
    ];

    for (final schedule in cases) {
      final medication = Medication(
        id: 'equivalence-med-${schedule.id}',
        name: 'Equivalence',
        dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
        startDate: DateTime(2026, 9, 6),
        schedules: [schedule],
      );
      final legacy = MedicationReminderCoordinator(_MedicationPort(), clock: () => now)
          .occurrences(
            medication,
            now: now,
            horizon: const Duration(days: 14),
            includeNoReminderSchedules: true,
          )
          .map((item) => item.dateTime)
          .toList();

      final rule = schedule.frequency == MedicationFrequency.daily
          ? const RecurrenceRule.daily()
          : RecurrenceRule.selectedWeekdays(schedule.selectedWeekdays.toSet());
      final expected = engine
          .occurrences(
            start: DateTime(2026, 9, 6, 9),
            rule: rule,
            windowStart: now,
            windowEnd: now.add(const Duration(days: 14, minutes: 1)),
          )
          .toList();

      expect(legacy, expected);
    }
  });
}
