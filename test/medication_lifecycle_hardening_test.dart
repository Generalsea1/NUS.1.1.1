import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/medications/application/medication_lifecycle_service.dart';
import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:nus/features/medications/domain/medication_reminder_port.dart';

class _EffectiveReminderPort implements MedicationReminderPort {
  final Map<String, ({String title, DateTime dateTime})> active = {};
  final List<String> scheduledCalls = [];
  final List<String> cancelledCalls = [];

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduledCalls.add(id);
    active[id] = (title: title, dateTime: dateTime);
  }

  @override
  Future<void> cancel(String id) async {
    cancelledCalls.add(id);
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
  String name = 'Private Medication',
  DateTime? startDate,
  DateTime? endDate,
  bool active = true,
  List<MedicationSchedule>? schedules,
}) => Medication(
      id: id,
      name: name,
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: startDate ?? _now,
      endDate: endDate,
      isActive: active,
      schedules: schedules ?? <MedicationSchedule>[_schedule()],
    );

MedicationReminderCoordinator _coordinator(_EffectiveReminderPort port) =>
    MedicationReminderCoordinator(port, clock: () => _now);

MedicationLifecycleService _service(_EffectiveReminderPort port) => MedicationLifecycleService(
      repository: LocalMedicationRepository(),
      reminders: _coordinator(port),
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

void _expectEffectiveSet(
  _EffectiveReminderPort port,
  Medication medication,
) {
  expect(
    port.active.map((id, value) => MapEntry(id, value.dateTime)),
    _effectiveReminderSet(medication),
  );
}

Future<void> _saveTransition(
  MedicationLifecycleService service,
  Medication previous,
  Medication current,
) async {
  await service.save(current, previous: previous);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('create builds the exact effective reminder set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(
      schedules: [
        _schedule(id: 'morning', minutes: 9 * 60),
        _schedule(id: 'evening', minutes: 21 * 60),
      ],
      endDate: DateTime(2026, 9, 5),
    );

    await service.save(medication);

    _expectEffectiveSet(port, medication);
    expect(port.active.keys, containsAll(<String>[
      MedicationReminderCoordinator.reminderId('m1', 'morning', DateTime(2026, 9, 3, 9)),
      MedicationReminderCoordinator.reminderId('m1', 'evening', DateTime(2026, 9, 3, 21)),
    ]));
  });

  test('unchanged edit leaves the exact effective set unchanged', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await service.save(medication);
    final before = Map<String, DateTime>.from(port.active.map((id, value) => MapEntry(id, value.dateTime)));
    await _saveTransition(service, medication, medication.copyWith(name: 'Renamed only'));

    final expected = _effectiveReminderSet(medication.copyWith(name: 'Renamed only'));
    expect(port.active.map((id, value) => MapEntry(id, value.dateTime)), expected);
    expect(port.active.length, before.length);
  });

  test('schedule time change removes the old effective reminder and keeps only the new one', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 5));
    final current = previous.copyWith(
      schedules: [_schedule(id: 's1', minutes: 10 * 60)],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.containsKey(
      MedicationReminderCoordinator.reminderId('m1', 's1', DateTime(2026, 9, 3, 9)),
    ), isFalse);
    expect(port.active.containsKey(
      MedicationReminderCoordinator.reminderId('m1', 's1', DateTime(2026, 9, 3, 10)),
    ), isTrue);
  });

  test('schedule removal leaves no stale reminder from the removed schedule', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(
      endDate: DateTime(2026, 9, 5),
      schedules: [
        _schedule(id: 'a', minutes: 9 * 60),
        _schedule(id: 'b', minutes: 21 * 60),
      ],
    );
    final current = previous.copyWith(schedules: [_schedule(id: 'a', minutes: 9 * 60)]);

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(
      port.active.keys,
      everyElement(isNot(MedicationReminderCoordinator.reminderId('m1', 'b', DateTime(2026, 9, 3, 21)))),
    );
  });

  test('schedule addition expands the effective set without stale or duplicate IDs', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 5));
    final current = previous.copyWith(
      schedules: [
        _schedule(id: 'a', minutes: 9 * 60),
        _schedule(id: 'b', minutes: 21 * 60),
      ],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.length, _effectiveReminderSet(current).length);
    expect(port.active.keys.toSet(), containsAll(_effectiveReminderSet(current).keys));
  });

  test('daily to selected weekdays leaves exactly the selected weekday set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 12));
    final current = previous.copyWith(
      schedules: [
        _schedule(
          frequency: MedicationFrequency.selectedWeekdays,
          weekdays: const [4, 6],
        ),
      ],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.values.every((item) => item.dateTime.weekday == 4 || item.dateTime.weekday == 6), isTrue);
  });

  test('selected weekdays to daily restores the exact daily effective set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(
      endDate: DateTime(2026, 9, 12),
      schedules: [
        _schedule(
          frequency: MedicationFrequency.selectedWeekdays,
          weekdays: const [4, 6],
        ),
      ],
    );
    final current = previous.copyWith(schedules: [_schedule()]);

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
  });

  test('weekday change cancels obsolete weekdays and leaves exactly the new set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(
      endDate: DateTime(2026, 9, 10),
      schedules: [
        _schedule(
          frequency: MedicationFrequency.selectedWeekdays,
          weekdays: const [1, 3],
        ),
      ],
    );
    final current = previous.copyWith(
      schedules: [
        _schedule(
          frequency: MedicationFrequency.selectedWeekdays,
          weekdays: const [2, 4],
        ),
      ],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.values.every((item) => item.dateTime.weekday == 2 || item.dateTime.weekday == 4), isTrue);
  });

  test('reminder offset change replaces effective reminder times without duplicate IDs', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 5));
    final current = previous.copyWith(
      schedules: [
        _schedule(reminder: MedicationReminder.fifteenMinutesBefore),
      ],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.length, _effectiveReminderSet(current).length);
    expect(port.active.values.first.dateTime, DateTime(2026, 9, 3, 8, 45));
  });

  test('active reminder to none leaves an empty effective set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 5));
    final current = previous.copyWith(
      schedules: [_schedule(reminder: MedicationReminder.none)],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active, isEmpty);
  });

  test('none to active reminder creates exactly the new effective set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(
      endDate: DateTime(2026, 9, 5),
      schedules: [_schedule(reminder: MedicationReminder.none)],
    );
    final current = previous.copyWith(
      schedules: [_schedule(reminder: MedicationReminder.sixtyMinutesBefore)],
    );

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
  });

  test('start date change leaves no reminders before the new start boundary', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 8));
    final current = previous.copyWith(startDate: DateTime(2026, 9, 6));

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.values.every((item) => !item.dateTime.isBefore(DateTime(2026, 9, 6, 9))), isTrue);
  });

  test('adding an end date cancels reminders beyond the inclusive end date', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication();
    final current = previous.copyWith(endDate: DateTime(2026, 9, 5));

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
    expect(port.active.values.every((item) => !item.dateTime.isAfter(DateTime(2026, 9, 5, 9))), isTrue);
  });

  test('shortening an end date removes all reminders beyond the new boundary', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 10));
    final current = previous.copyWith(endDate: DateTime(2026, 9, 5));

    await service.save(previous);
    await _saveTransition(service, previous, current);

    _expectEffectiveSet(port, current);
  });

  test('deactivation leaves medication data intact and the effective reminder set empty', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await service.save(medication);
    await service.setActive(medication, false);

    final stored = await service.repository.getById('m1');
    expect(stored, isNotNull);
    expect(stored!.isActive, isFalse);
    expect(stored.schedules, medication.schedules);
    expect(port.active, isEmpty);
  });

  test('reactivation restores exactly the effective reminder set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await service.save(medication);
    final inactive = medication.copyWith(isActive: false);
    await service.setActive(medication, false);
    await service.setActive(inactive, true);

    final stored = await service.repository.getById('m1');
    expect(stored!.isActive, isTrue);
    _expectEffectiveSet(port, stored);
  });

  test('delete removes the persisted record and leaves no effective reminders', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await service.save(medication);
    await service.delete(medication);

    expect(await service.repository.getById('m1'), isNull);
    expect(port.active, isEmpty);
  });

  test('repeated identical synchronization converges to one exact effective set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final medication = _medication(endDate: DateTime(2026, 9, 5));

    await service.save(medication);
    await service.save(medication, previous: medication);
    await service.save(medication, previous: medication);

    _expectEffectiveSet(port, medication);
    expect(port.active.length, _effectiveReminderSet(medication).length);
    expect(port.active.keys.toSet(), _effectiveReminderSet(medication).keys.toSet());
  });

  test('two medications remain isolated by their effective reminder IDs', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final first = _medication(id: 'm1', endDate: DateTime(2026, 9, 5));
    final second = _medication(id: 'm2', endDate: DateTime(2026, 9, 5));

    await service.save(first);
    await service.save(second);
    await service.delete(first);

    expect(port.active.keys, _effectiveReminderSet(second).keys.toSet());
  });

  test('repository reload preserves the medication definition used to derive the effective set', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final firstRepository = LocalMedicationRepository(preferences: prefs);
    final medication = _medication(
      endDate: DateTime(2026, 9, 5),
      schedules: [
        _schedule(id: 'a', minutes: 9 * 60),
        _schedule(id: 'b', minutes: 18 * 60, reminder: MedicationReminder.fifteenMinutesBefore),
      ],
    );

    await firstRepository.save(medication);
    final reloaded = (await LocalMedicationRepository(preferences: prefs).list()).single;

    expect(reloaded.toJson(), medication.toJson());
    expect(_effectiveReminderSet(reloaded), _effectiveReminderSet(medication));
  });

  test('invalid save preserves the previously persisted medication and its effective set', () async {
    final port = _EffectiveReminderPort();
    final service = _service(port);
    final previous = _medication(endDate: DateTime(2026, 9, 5));
    final invalid = previous.copyWith(name: ' ');

    await service.save(previous);
    final before = Map<String, DateTime>.from(port.active.map((id, value) => MapEntry(id, value.dateTime)));

    await expectLater(service.save(invalid, previous: previous), throwsA(isA<ArgumentError>()));

    final stored = await service.repository.getById('m1');
    expect(stored!.toJson(), previous.toJson());
    expect(port.active.map((id, value) => MapEntry(id, value.dateTime)), before);
  });
}