import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/appointments/application/appointment_lifecycle_service.dart';
import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/today/presentation/nus_quick_add_page.dart';

class _FakeAppointmentRepository implements AppointmentRepository {
  final List<Appointment> items = [];

  @override
  Future<Appointment?> getById(String id) async => items.cast<Appointment?>().firstWhere(
        (item) => item?.id == id,
        orElse: () => null,
      );

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

    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pumpAndSettle();

    expect(repository.items, hasLength(1));
    expect(repository.items.single.title, 'موعد دكتور');
    expect(repository.items.single.type, AppointmentType.doctor);
    expect(repository.items.single.startsAt, DateTime(2026, 9, 10, 10));
  });
}
