import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/data/medication_reminder_adapter.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:nus/features/medications/domain/medication_reminder_port.dart';
import 'package:nus/notification_service.dart';

class FakeMedicationReminderPort implements MedicationReminderPort {
  final scheduled = <({String id, String title, DateTime dateTime})>[];
  final cancelled = <String>[];

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduled.add((id: id, title: title, dateTime: dateTime));
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}

class FakeReminderScheduler implements ReminderScheduler {
  final scheduled = <({String id, String title, DateTime dateTime})>[];
  final cancelled = <String>[];

  @override
  Future<void> scheduleReminder({
    required String id,
    required String title,
    required DateTime dateTime,
  }) async {
    scheduled.add((id: id, title: title, dateTime: dateTime));
  }

  @override
  Future<void> cancelReminder(String id) async {
    cancelled.add(id);
  }
}

MedicationSchedule schedule({
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

Medication medication({
  String id = 'm1',
  String name = 'Private Medication',
  String amount = '1',
  DateTime? startDate,
  DateTime? endDate,
  bool active = true,
  List<MedicationSchedule>? schedules,
}) => Medication(
      id: id,
      name: name,
      dosage: Dosage(amount: amount, unit: DosageUnit.tablet),
      startDate: startDate ?? DateTime(2026, 9, 3),
      endDate: endDate,
      isActive: active,
      schedules: schedules ?? <MedicationSchedule>[schedule()],
    );

final fixedNow = DateTime(2026, 9, 3, 8);

MedicationReminderCoordinator coordinator(FakeMedicationReminderPort port) =>
    MedicationReminderCoordinator(port, clock: () => fixedNow);

void main() {
  test('adapter delegates scheduling and cancellation to ReminderScheduler', () async {
    final scheduler = FakeReminderScheduler();
    final adapter = MedicationReminderAdapter(scheduler);
    final at = DateTime(2026, 9, 3, 9);

    await adapter.schedule(id: '123', title: 'Medication', dateTime: at);
    await adapter.cancel('123');

    expect(scheduler.scheduled.single.dateTime, at);
    expect(scheduler.scheduled.single.id, '123');
    expect(scheduler.cancelled, ['123']);
  });

  test('deterministic reminder ID is stable for identical input', () {
    final at = DateTime(2026, 9, 3, 9);
    expect(
      MedicationReminderCoordinator.reminderId('m1', 's1', at),
      MedicationReminderCoordinator.reminderId('m1', 's1', at),
    );
  });

  test('different medication IDs produce different reminder IDs', () {
    final at = DateTime(2026, 9, 3, 9);
    expect(
      MedicationReminderCoordinator.reminderId('m1', 's1', at),
      isNot(MedicationReminderCoordinator.reminderId('m2', 's1', at)),
    );
  });

  test('different schedule IDs produce different reminder IDs', () {
    final at = DateTime(2026, 9, 3, 9);
    expect(
      MedicationReminderCoordinator.reminderId('m1', 's1', at),
      isNot(MedicationReminderCoordinator.reminderId('m1', 's2', at)),
    );
  });

  test('different occurrence dates and times produce different reminder IDs', () {
    final first = DateTime(2026, 9, 3, 9);
    final nextDate = DateTime(2026, 9, 4, 9);
    final nextTime = DateTime(2026, 9, 3, 10);
    expect(
      MedicationReminderCoordinator.reminderId('m1', 's1', first),
      isNot(MedicationReminderCoordinator.reminderId('m1', 's1', nextDate)),
    );
    expect(
      MedicationReminderCoordinator.reminderId('m1', 's1', first),
      isNot(MedicationReminderCoordinator.reminderId('m1', 's1', nextTime)),
    );
  });

  test('reminder ID contains no medication name or dosage', () {
    final id = MedicationReminderCoordinator.reminderId(
      'm-private',
      'schedule-private',
      DateTime(2026, 9, 3, 9),
    );
    expect(id, isNot(contains('Private')));
    expect(id, isNot(contains('1')));
    expect(id, matches(RegExp(r'^\d+$')));
  });

  test('daily occurrence generation respects the 30-day horizon', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(medication());

    expect(port.scheduled, hasLength(30));
    expect(port.scheduled.first.dateTime, fixedNow.copyWith(hour: 9));
    expect(port.scheduled.last.dateTime, DateTime(2026, 10, 2, 9));
  });

  test('selected weekday occurrence generation includes only selected weekdays', () async {
    final port = FakeMedicationReminderPort();
    final med = medication(
      schedules: [
        schedule(
          frequency: MedicationFrequency.selectedWeekdays,
          weekdays: const [4, 6],
        ),
      ],
    );

    await coordinator(port).sync(med);

    expect(port.scheduled, isNotEmpty);
    expect(port.scheduled.every((item) => item.dateTime.weekday == 4 || item.dateTime.weekday == 6), isTrue);
  });

  test('startDate boundary excludes occurrences before startDate', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(medication(startDate: DateTime(2026, 9, 5)));

    expect(port.scheduled.first.dateTime, DateTime(2026, 9, 5, 9));
  });

  test('endDate is inclusive', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(
      medication(endDate: DateTime(2026, 9, 5)),
    );

    expect(port.scheduled.map((item) => item.dateTime), [
      DateTime(2026, 9, 3, 9),
      DateTime(2026, 9, 4, 9),
      DateTime(2026, 9, 5, 9),
    ]);
  });

  test('occurrences after endDate are excluded', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(medication(endDate: DateTime(2026, 9, 4)));

    expect(
      port.scheduled.every((item) => !item.dateTime.isAfter(DateTime(2026, 9, 4, 23, 59))),
      isTrue,
    );
  });

  test('inactive medication schedules nothing', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(medication(active: false));

    expect(port.scheduled, isEmpty);
    expect(port.cancelled, isNotEmpty);
  });

  test('reminder none schedules nothing', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(
      medication(schedules: [schedule(reminder: MedicationReminder.none)]),
    );

    expect(port.scheduled, isEmpty);
  });

  test('supported reminder offsets map correctly', () {
    final occurrence = DateTime(2026, 9, 4, 9);
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.atTime), occurrence);
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.fiveMinutesBefore), DateTime(2026, 9, 4, 8, 55));
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.fifteenMinutesBefore), DateTime(2026, 9, 4, 8, 45));
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.thirtyMinutesBefore), DateTime(2026, 9, 4, 8, 30));
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.sixtyMinutesBefore), DateTime(2026, 9, 4, 8));
    expect(MedicationReminderCoordinator.reminderDateTime(occurrence, MedicationReminder.oneDayBefore), DateTime(2026, 9, 3, 9));
  });

  test('past occurrences and past reminder times are excluded', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(
      medication(
        schedules: [
          schedule(minutes: 7 * 60),
          schedule(id: 'future', minutes: 9 * 60),
        ],
      ),
    );

    expect(port.scheduled.every((item) => item.dateTime.isAfter(fixedNow)), isTrue);
    expect(port.scheduled.any((item) => item.id ==
        MedicationReminderCoordinator.reminderId('m1', 's1', DateTime(2026, 9, 3, 7))), isFalse);
  });

  test('one-day-before reminder is scheduled only when offset remains future', () async {
    final port = FakeMedicationReminderPort();
    await coordinator(port).sync(
      medication(
        schedules: [schedule(reminder: MedicationReminder.oneDayBefore)],
        startDate: DateTime(2026, 9, 4),
      ),
    );

    expect(port.scheduled.first.dateTime, DateTime(2026, 9, 3, 9));
  });

  test('cancellation produces deterministic reminder IDs', () async {
    final port = FakeMedicationReminderPort();
    final med = medication(endDate: DateTime(2026, 9, 5));
    await coordinator(port).cancel(med);

    final expected = <String>{
      for (final date in [3, 4, 5])
        MedicationReminderCoordinator.reminderId('m1', 's1', DateTime(2026, 9, date, 9)),
    };
    expect(port.cancelled.toSet(), expected);
  });

  test('sync cancels managed IDs before rebuilding active reminders', () async {
    final port = FakeMedicationReminderPort();
    final med = medication(endDate: DateTime(2026, 9, 5));
    await coordinator(port).sync(med);

    expect(port.cancelled, isNotEmpty);
    expect(port.scheduled, isNotEmpty);
  });

  test('repeated synchronization preserves the same logical reminder ID set', () async {
    final port = FakeMedicationReminderPort();
    final med = medication(endDate: DateTime(2026, 9, 4));
    final c = coordinator(port);

    await c.sync(med);
    final first = port.scheduled.map((item) => item.id).toSet();
    final firstScheduleCount = port.scheduled.length;

    await c.sync(med);
    final second = port.scheduled.skip(firstScheduleCount).map((item) => item.id).toSet();

    expect(second, first);
    expect(port.cancelled, isNotEmpty);
  });

  test('sync with previous definition cancels removed schedule IDs', () async {
    final port = FakeMedicationReminderPort();
    final previous = medication(
      schedules: [schedule(id: 'old')],
      endDate: DateTime(2026, 9, 4),
    );
    final current = medication(
      schedules: [schedule(id: 'new')],
      endDate: DateTime(2026, 9, 4),
    );

    await coordinator(port).sync(current, previous: previous);

    final oldId = MedicationReminderCoordinator.reminderId('m1', 'old', DateTime(2026, 9, 3, 9));
    final newId = MedicationReminderCoordinator.reminderId('m1', 'new', DateTime(2026, 9, 3, 9));
    expect(port.cancelled, contains(oldId));
    expect(port.scheduled.map((item) => item.id), contains(newId));
  });

  test('invalid medication data is rejected without scheduling', () async {
    final port = FakeMedicationReminderPort();
    final invalid = Medication(
      id: 'm1',
      name: ' ',
      dosage: const Dosage(amount: '', unit: DosageUnit.tablet),
      startDate: DateTime(2026, 9, 3),
      schedules: [schedule()],
    );

    await coordinator(port).sync(invalid);
    expect(port.scheduled, isEmpty);
  });

  test('different schedule occurrences remain unique across a two-schedule medication', () async {
    final port = FakeMedicationReminderPort();
    final med = medication(
      endDate: DateTime(2026, 9, 4),
      schedules: [
        schedule(id: 'morning', minutes: 9 * 60),
        schedule(id: 'evening', minutes: 21 * 60),
      ],
    );

    await coordinator(port).sync(med);

    expect(port.scheduled.map((item) => item.id).toSet(), hasLength(4));
  });
}
