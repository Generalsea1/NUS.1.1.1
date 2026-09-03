import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/domain/domain_entity.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:shared_preferences/shared_preferences.dart';

MedicationSchedule dailySchedule({String id = 'morning', MedicationReminder reminder = MedicationReminder.atTime}) =>
    MedicationSchedule(
      id: id,
      minutesSinceMidnight: 8 * 60,
      frequency: MedicationFrequency.daily,
      reminder: reminder,
    );

Medication makeMedication({String id = 'm1', String name = 'Vitamin'}) =>
    Medication(
      id: id,
      name: name,
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      instructions: 'After breakfast',
      notes: 'Keep in cabinet',
      startDate: DateTime(2026, 9, 3, 14, 30),
      endDate: DateTime(2026, 9, 10, 23, 59),
      schedules: <MedicationSchedule>[dailySchedule()],
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Medication implements DomainEntity', () {
    expect(makeMedication(), isA<DomainEntity>());
  });

  test('valid Medication construction', () {
    final medication = makeMedication();
    expect(medication.startDate, DateTime(2026, 9, 3));
    expect(medication.endDate, DateTime(2026, 9, 10));
    expect(medication.schedules, hasLength(1));
    expect(MedicationValidator.validate(medication), isEmpty);
  });

  test('invalid empty name', () {
    final medication = makeMedication(name: ' ');
    expect(MedicationValidator.validate(medication), contains('name_required'));
  });

  test('invalid empty dosage amount', () {
    const dosage = Dosage(amount: ' ', unit: DosageUnit.tablet);
    expect(dosage.validate(), contains('amount_required'));
  });

  test('invalid custom unit', () {
    const dosage = Dosage(amount: '1', unit: DosageUnit.custom);
    expect(dosage.validate(), contains('custom_unit_required'));
    expect(
      const Dosage(amount: '1', unit: DosageUnit.tablet, customUnit: 'box').validate(),
      contains('custom_unit_not_allowed'),
    );
  });

  test('invalid empty schedules', () {
    final medication = Medication(
      id: 'm1',
      name: 'Vitamin',
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: DateTime(2026, 9, 3),
      schedules: <MedicationSchedule>[],
    );
    expect(MedicationValidator.validate(medication), contains('schedules_required'));
  });

  test('invalid schedule time', () {
    final schedule = MedicationSchedule(
      id: 'bad',
      minutesSinceMidnight: 1440,
      frequency: MedicationFrequency.daily,
    );
    expect(schedule.validate(), contains('schedule_time_invalid'));
  });

  test('duplicate schedule IDs', () {
    final scheduleA = dailySchedule(id: 'same');
    final scheduleB = scheduleA.copyWith(minutesSinceMidnight: 9 * 60);
    final medication = Medication(
      id: 'm1',
      name: 'Vitamin',
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: DateTime(2026, 9, 3),
      schedules: <MedicationSchedule>[scheduleA, scheduleB],
    );
    expect(MedicationValidator.validate(medication), contains('schedule_id_duplicate'));
  });

  test('valid daily schedule', () {
    final schedule = dailySchedule();
    expect(schedule.frequency, MedicationFrequency.daily);
    expect(schedule.selectedWeekdays, isEmpty);
    expect(schedule.validate(), isEmpty);
  });

  test('valid selected-weekday schedule', () {
    final schedule = MedicationSchedule(
      id: 'weekdays',
      minutesSinceMidnight: 21 * 60,
      frequency: MedicationFrequency.selectedWeekdays,
      selectedWeekdays: <int>[1, 3, 5],
      reminder: MedicationReminder.fifteenMinutesBefore,
    );
    expect(schedule.validate(), isEmpty);
  });

  test('invalid selected weekdays are rejected', () {
    final duplicate = MedicationSchedule(
      id: 'bad',
      minutesSinceMidnight: 12 * 60,
      frequency: MedicationFrequency.selectedWeekdays,
      selectedWeekdays: <int>[1, 1, 8],
    );
    final invalid = duplicate.validate();
    expect(invalid, contains('weekday_invalid'));
    expect(invalid, contains('weekday_duplicate'));
  });

  test('invalid end date', () {
    final medication = makeMedicationWithDates(
      startDate: DateTime(2026, 9, 10),
      endDate: DateTime(2026, 9, 9),
    );
    expect(MedicationValidator.validate(medication), contains('end_date_before_start_date'));
  });

  test('Medication JSON round-trip', () {
    final medication = makeMedication();
    final restored = Medication.fromJson(medication.toJson());
    expect(restored.toJson(), medication.toJson());
  });

  test('Dosage JSON round-trip', () {
    const dosage = Dosage(amount: '0.5', unit: DosageUnit.custom, customUnit: 'scoop');
    expect(Dosage.fromJson(dosage.toJson()).toJson(), dosage.toJson());
  });

  test('Schedule JSON round-trip', () {
    final schedule = MedicationSchedule(
      id: 'night',
      minutesSinceMidnight: 23 * 60 + 15,
      frequency: MedicationFrequency.selectedWeekdays,
      selectedWeekdays: <int>[7, 1, 4],
      reminder: MedicationReminder.oneDayBefore,
    );
    final restored = MedicationSchedule.fromJson(schedule.toJson());
    expect(restored.toJson(), schedule.toJson());
    expect(restored.selectedWeekdays, <int>[1, 4, 7]);
  });

  test('LocalMedicationRepository save', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication());
    expect(await repository.getById('m1'), isNotNull);
  });

  test('LocalMedicationRepository getById', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication(id: 'm1'));
    await repository.save(makeMedication(id: 'm2', name: 'Other'));
    expect((await repository.getById('m2'))!.name, 'Other');
  });

  test('LocalMedicationRepository list', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication(id: 'm1'));
    await repository.save(makeMedication(id: 'm2'));
    expect(await repository.list(), hasLength(2));
  });

  test('LocalMedicationRepository update', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication());
    await repository.save(makeMedication(name: 'Updated'));
    final stored = await repository.getById('m1');
    expect(stored!.name, 'Updated');
    expect((await repository.list()).where((item) => item.id == 'm1'), hasLength(1));
  });

  test('LocalMedicationRepository delete', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication());
    await repository.deleteById('m1');
    expect(await repository.getById('m1'), isNull);
  });

  test('persistence survives repository recreation', () async {
    await LocalMedicationRepository().save(makeMedication());
    final recreated = LocalMedicationRepository();
    expect((await recreated.getById('m1'))!.name, 'Vitamin');
  });

  test('malformed record isolation', () async {
    final good = makeMedication(id: 'good').toJson();
    SharedPreferences.setMockInitialValues({
      LocalMedicationRepository.storageKey: jsonEncode(<dynamic>[good, <String, dynamic>{'id': 'bad'}]),
    });
    expect((await LocalMedicationRepository().list()).map((item) => item.id), <String>['good']);
  });

  test('malformed root payload isolation', () async {
    SharedPreferences.setMockInitialValues({
      LocalMedicationRepository.storageKey: '{not valid json',
    });
    expect(await LocalMedicationRepository().list(), isEmpty);
  });

  test('deterministic ordering', () async {
    final repository = LocalMedicationRepository();
    await repository.save(makeMedication(id: 'z', name: 'Z'));
    await repository.save(makeMedication(id: 'a', name: 'A').copyWith(isActive: false));
    await repository.save(makeMedication(id: 'b', name: 'B').copyWith(startDate: DateTime(2026, 9, 4)));
    expect((await repository.list()).map((item) => item.id), <String>['z', 'b', 'a']);
  });

  test('duplicate medication IDs are handled safely', () async {
    final first = makeMedication(id: 'dup', name: 'First').toJson();
    final second = makeMedication(id: 'dup', name: 'Second').toJson();
    SharedPreferences.setMockInitialValues({
      LocalMedicationRepository.storageKey: jsonEncode(<dynamic>[first, second]),
    });
    final repository = LocalMedicationRepository();
    expect((await repository.list()).single.name, 'First');
    await repository.save(makeMedication(id: 'dup', name: 'Updated'));
    final decoded = jsonDecode(
      (await SharedPreferences.getInstance()).getString(LocalMedicationRepository.storageKey)!,
    ) as List;
    expect(decoded, hasLength(1));
    expect(decoded.single['name'], 'Updated');
  });

  test('MedicationSchedule protects selected weekdays from external mutation', () {
    final weekdays = <int>[1, 2];
    final schedule = MedicationSchedule(
      id: 'protected',
      minutesSinceMidnight: 60,
      frequency: MedicationFrequency.selectedWeekdays,
      selectedWeekdays: weekdays,
    );
    weekdays.add(3);
    expect(schedule.selectedWeekdays, <int>[1, 2]);
  });
}

Medication makeMedicationWithDates({required DateTime startDate, required DateTime endDate}) =>
    Medication(
      id: 'm1',
      name: 'Vitamin',
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: startDate,
      endDate: endDate,
      schedules: <MedicationSchedule>[dailySchedule()],
    );
