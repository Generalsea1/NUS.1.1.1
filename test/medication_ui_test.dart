// Medication UI tests exercise presentation navigation and the application
// lifecycle boundary without touching NotificationService directly.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/medications/application/medication_lifecycle_service.dart';
import 'package:nus/features/medications/application/medication_reminder_coordinator.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/medications/domain/medication.dart';
import 'package:nus/features/medications/domain/medication_reminder_port.dart';
import 'package:nus/features/medications/presentation/medication_editor_page.dart';
import 'package:nus/features/medications/presentation/medications_page.dart';

class _FakeReminderPort implements MedicationReminderPort {
  final scheduled = <String>[];
  final cancelled = <String>[];

  @override
  Future<void> schedule({required String id, required String title, required DateTime dateTime}) async {
    scheduled.add(id);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
  }
}

class _FailingRepository implements MedicationRepository {
  bool saveCalled = false;

  @override
  Future<Medication?> getById(String id) async => null;

  @override
  Future<List<Medication>> list() async => <Medication>[];

  @override
  Future<void> save(Medication entity) async {
    saveCalled = true;
    throw ArgumentError('save failed');
  }

  @override
  Future<void> deleteById(String id) async {}
}

Medication _medication({String id = 'm1', bool active = true}) => Medication(
      id: id,
      name: 'Daily medicine',
      dosage: const Dosage(amount: '1', unit: DosageUnit.tablet),
      startDate: DateTime(2026, 9, 3),
      isActive: active,
      schedules: [
        MedicationSchedule(
          id: 's1',
          minutesSinceMidnight: 9 * 60,
          frequency: MedicationFrequency.daily,
          reminder: MedicationReminder.atTime,
        ),
      ],
    );

MedicationLifecycleService _service(_FakeReminderPort port) => MedicationLifecycleService(
      repository: LocalMedicationRepository(),
      reminders: MedicationReminderCoordinator(port, clock: () => DateTime(2026, 9, 3, 8)),
    );

Future<void> _pumpPage(WidgetTester tester, MedicationLifecycleService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: MedicationsPage(service: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final finder = find.byKey(const Key('medication_editor_save'), skipOffstage: false);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('empty medication state is shown', (tester) async {
    final port = _FakeReminderPort();
    await _pumpPage(tester, _service(port));

    expect(find.text('لسه مفيش أدوية'), findsOneWidget);
    expect(find.text('إضافة دواء'), findsWidgets);
  });

  testWidgets('create valid medication persists through the application boundary', (tester) async {
    final port = _FakeReminderPort();
    final service = _service(port);
    await _pumpPage(tester, service);

    await tester.tap(find.text('إضافة دواء').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Morning medicine');
    await tester.enterText(find.byType(TextField).at(1), '2');
    await _tapSave(tester);

    expect((await service.repository.list()).single.name, 'Morning medicine');
    expect(port.scheduled, isNotEmpty);
    expect(find.text('Morning medicine'), findsOneWidget);
  });

  testWidgets('invalid medication is blocked by UI validation', (tester) async {
    final port = _FakeReminderPort();
    await _pumpPage(tester, _service(port));

    await tester.tap(find.text('إضافة دواء').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '1');
    await _tapSave(tester);

    expect(find.text('اسم الدواء مطلوب.'), findsOneWidget);
    expect(find.byType(MedicationEditorPage), findsOneWidget);
  });

  testWidgets('edit flow updates an existing medication', (tester) async {
    final port = _FakeReminderPort();
    final service = _service(port);
    await service.repository.save(_medication());
    await _pumpPage(tester, service);

    await tester.tap(find.text('Daily medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Edited medicine');
    await _tapSave(tester);

    expect((await service.repository.getById('m1'))!.name, 'Edited medicine');
  });

  testWidgets('deactivate and reactivate preserve medication and resynchronize reminders', (tester) async {
    final port = _FakeReminderPort();
    final service = _service(port);
    await service.repository.save(_medication());
    await _pumpPage(tester, service);

    await tester.tap(find.text('Daily medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إيقاف الدواء'));
    await tester.pumpAndSettle();

    expect((await service.repository.getById('m1'))!.isActive, isFalse);
    expect(port.cancelled, isNotEmpty);

    await tester.tap(find.text('Daily medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تفعيل الدواء'));
    await tester.pumpAndSettle();

    expect((await service.repository.getById('m1'))!.isActive, isTrue);
    expect(port.scheduled, isNotEmpty);
  });

  testWidgets('delete flow removes medication and cancels managed reminders', (tester) async {
    final port = _FakeReminderPort();
    final service = _service(port);
    await service.repository.save(_medication());
    await _pumpPage(tester, service);

    await tester.tap(find.text('Daily medicine'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(await service.repository.getById('m1'), isNull);
    expect(port.cancelled, isNotEmpty);
  });

  testWidgets('schedule editor exposes supported recurrence and reminder choices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MedicationEditorPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إضافة', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('التكرار'), findsOneWidget);
    expect(find.text('التذكير'), findsOneWidget);
    expect(find.text('أيام محددة'), findsNothing);
  });

  test('weekday validation blocks a selected-weekday schedule with no weekday', () {
    final schedule = MedicationSchedule(
      id: 's1',
      minutesSinceMidnight: 9 * 60,
      frequency: MedicationFrequency.selectedWeekdays,
      reminder: MedicationReminder.atTime,
    );
    expect(schedule.validate(), contains('weekday_required'));
  });

  test('reminder synchronization is never called before a successful repository save', () async {
    final repository = _FailingRepository();
    final port = _FakeReminderPort();
    final service = MedicationLifecycleService(
      repository: repository,
      reminders: MedicationReminderCoordinator(port, clock: () => DateTime(2026, 9, 3, 8)),
    );

    await expectLater(service.save(_medication()), throwsA(isA<ArgumentError>()));
    expect(repository.saveCalled, isTrue);
    expect(port.scheduled, isEmpty);
    expect(port.cancelled, isEmpty);
  });
}
