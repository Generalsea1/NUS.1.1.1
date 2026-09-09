import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/appointments/application/appointment_lifecycle_service.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/today/presentation/nus_quick_add_page.dart';

class _FakeAppointmentRepository implements AppointmentRepository {
  final List<Appointment> items = [];

  @override
  Future<Appointment?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<Appointment>> list() async => List<Appointment>.from(items);

  @override
  Future<void> save(Appointment entity) async {
    final index = items.indexWhere((item) => item.id == entity.id);
    if (index == -1) {
      items.add(entity);
    } else {
      items[index] = entity;
    }
  }

  @override
  Future<void> deleteById(String id) async => items.removeWhere((item) => item.id == id);
}

void main() {
  testWidgets('routes an explicit appointment through the lifecycle service', (tester) async {
    final repository = _FakeAppointmentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (_, __) async {},
          appointmentService: AppointmentLifecycleService(repository: repository),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'موعد دكتور بكرة الساعة 10',
    );
    await tester.pump();

    expect(
      find.text('NUS فهمها كـ موعد'),
      findsOneWidget,
    );

    final saveFinder = find.byKey(const ValueKey<String>('quick-add-save'));
    await tester.ensureVisible(saveFinder);
    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    expect(repository.items, hasLength(1));
    expect(repository.items.single.title, 'موعد دكتور');
    expect(repository.items.single.type, AppointmentType.doctor);
    expect(repository.items.single.startsAt.year, DateTime.now().year);
    expect(repository.items.single.startsAt.month, DateTime.now().month);
    expect(repository.items.single.startsAt.day, DateTime.now().add(const Duration(days: 1)).day);
    expect(repository.items.single.startsAt.hour, 10);
  });
}
