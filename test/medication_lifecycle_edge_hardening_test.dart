import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/appointments/application/appointment_reminder_coordinator.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/appointments/domain/appointment_reminder_port.dart';
import 'package:nus/features/medications/application/medication_lifecycle_service.dart';
import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:nus/features/medications/domain/medication_reminder_port.dart';
import 'package:nus/features/medications/presentation/medication_editor_page.dart';
import 'package:nus/features/medications/presentation/medications_page.dart';

class _ActiveReminderPort implements MedicationReminderPort {
  final Map<String, ({String title, DateTime dateTime})> active = {};
  final List<({String id, String title, DateTime dateTime})> activeEntries = [];

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    activeEntries.add((id: id, title: title, dateTime: dateTime));
    active[id] = (title: title, dateTime: dateTime);
  }

  @override
  Future<void> cancel(String id) async {
    activeEntries.removeWhere((entry) => entry.id == id);
    active.remove(id);
  }
}

class _SharedReminderPort implements MedicationReminderPort, AppointmentReminderPort {
  final Map<String, ({String title, DateTime dateTime})> active = {};

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    active[id] = (title: title, dateTime: dateTime);
  }

  @override
  Future<void> cancel(String id) async {
    active.remove(id);
  }
}

final _now = DateTime(2026, 9, 3, 8);

MedicationSchedule _schedule({
  String id = 's1',
  int minutes = 9 * 60,
  MedicationFrequency frequency = MedicationFrequency.daily,
  List<int> weekdays = const <int>[],
  MedicationReminder reminder = MedicationReminder.atTime,
}) => MedicationSchedule(
      id: id,
      minutesSinceMidnight: minutes,
      frequency: frequency,
      selectedWeekdays: weekdays,
      reminder: reminder,
    );

Medication _medication({
  String id = 'm1',
  DateTime? startDate,
  DateTime? endDate,
  bool active = true,
  List<MedicationSchedule>? schedules,
}) => Medication(
      id: id,
      name: 'Private Medication',
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: startDate ?? _now,
      endDate: endDate,
      isActive: active,
      schedules: schedules ?? <MedicationSchedule>[_schedule()],
    );

Map<String, DateTime> _effectiveReminderSet(Medication medication) => {
      for (final item in MedicationReminderCoordinator.occurrences(
        medication,
        now: _now,
        horizon: const Duration(days: 30),
      ))
        if (MedicationReminderCoordinator
            .reminderDateTime(item.dateTime, item.schedule.reminder)
            .isAfter(_now))
          MedicationReminderCoordinator.reminderId(
            medication.id,
            item.schedule.id,
            item.dateTime,
          ): MedicationReminderCoordinator.reminderDateTime(
            item.dateTime,
            item.schedule.reminder,
          ),
    };

void _expectExactEffectiveSet(
  _ActiveReminderPort port,
  Medication medication,
) {
  final expected = _effectiveReminderSet(medication);
  final actual = port.active.map((id, value) => MapEntry(id, value.dateTime));
  expect(actual, expected);
  expect(port.activeEntries.length, expected.length);
  expect(
    port.activeEntries.map((entry) => entry.id).toSet().length,
    port.activeEntries.length,
  );
}

MedicationLifecycleService _service(_ActiveReminderPort port) => MedicationLifecycleService(
      repository: LocalMedicationRepository(),
      reminders: MedicationReminderCoordinator(port, clock: () => _now),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('repeated edit/save cycles converge to the exact effective set without logical duplicates', () async {
    final port = _ActiveReminderPort();
    final service = _service(port);
    var previous = _medication(endDate: DateTime(2026, 9, 10));

    await service.save(previous);
    _expectExactEffectiveSet(port, previous);

    final edits = <Medication>[
      previous.copyWith(
        schedules: [_schedule(id: 's1', minutes: 10 * 60)],
      ),
      previous.copyWith(
        schedules: [_schedule(id: 's1', minutes: 10 * 60, reminder: MedicationReminder.fifteenMinutesBefore)],
      ),
      previous.copyWith(
        schedules: [
          _schedule(id: 's1', minutes: 10 * 60, reminder: MedicationReminder.fifteenMinutesBefore),
          _schedule(id: 's2', minutes: 21 * 60),
        ],
      ),
      previous.copyWith(
        schedules: [
          _schedule(
            id: 's1',
            frequency: MedicationFrequency.selectedWeekdays,
            weekdays: const [4, 6],
            minutes: 10 * 60,
            reminder: MedicationReminder.fifteenMinutesBefore,
          ),
        ],
      ),
    ];

    for (final current in edits) {
      await service.save(current, previous: previous);
      _expectExactEffectiveSet(port, current);
      previous = current;
    }
  });

  testWidgets('cancelled medication edit leaves persisted state and effective reminders unchanged', (tester) async {
    final port = _ActiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));
    await service.save(medication);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MedicationsPage(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final beforeMedication = (await service.repository.getById('m1'))!;
    final beforeReminders = Map<String, DateTime>.from(
      port.active.map((id, value) => MapEntry(id, value.dateTime)),
    );

    await tester.tap(find.text('Private Medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(MedicationEditorPage), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Changed but cancelled');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final afterMedication = (await service.repository.getById('m1'))!;
    final afterReminders = port.active.map((id, value) => MapEntry(id, value.dateTime));

    expect(afterMedication.toJson(), beforeMedication.toJson());
    expect(afterReminders, beforeReminders);
    _expectExactEffectiveSet(port, beforeMedication);
  });

  test('medication lifecycle does not cancel or replace Appointment reminders', () async {
    final shared = _SharedReminderPort();
    final appointmentCoordinator = AppointmentReminderCoordinator(shared);
    final appointment = Appointment(
      id: 'appointment-1',
      title: 'Appointment',
      type: AppointmentType.personal,
      startsAt: _now.add(const Duration(hours: 2)),
      reminder: AppointmentReminder.atTime,
      recurrence: AppointmentRecurrence.none,
      status: AppointmentStatus.upcoming,
    );

    await appointmentCoordinator.sync(appointment);
    final appointmentOnlyState = Map<String, DateTime>.from(
      shared.active.map((id, value) => MapEntry(id, value.dateTime)),
    );
    expect(appointmentOnlyState, isNotEmpty);

    final medicationService = MedicationLifecycleService(
      repository: LocalMedicationRepository(),
      reminders: MedicationReminderCoordinator(shared, clock: () => _now),
    );
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await medicationService.save(medication);
    await medicationService.delete(medication);

    expect(
      shared.active.map((id, value) => MapEntry(id, value.dateTime)),
      appointmentOnlyState,
    );
  });
}