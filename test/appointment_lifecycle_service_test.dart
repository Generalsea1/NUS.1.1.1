import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/appointments/application/appointment_lifecycle_service.dart';
import 'package:nus/features/appointments/domain/appointment.dart';

class _MemoryAppointmentRepository implements AppointmentRepository {
  final List<Appointment> items = [];

  @override
  Future<Appointment?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<Appointment>> list() async => List<Appointment>.of(items);

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
  Future<void> deleteById(String id) async {
    items.removeWhere((item) => item.id == id);
  }
}

void main() {
  test('creates a valid appointment and prevents semantic duplicates', () async {
    final repository = _MemoryAppointmentRepository();
    final service = AppointmentLifecycleService(repository: repository);
    final startsAt = DateTime.now().add(const Duration(days: 1));

    final first = await service.create(
      title: 'موعد مهم',
      startsAt: startsAt,
      type: AppointmentType.personal,
    );
    final duplicate = await service.create(
      title: '  موعد مهم  ',
      startsAt: startsAt,
      type: AppointmentType.personal,
    );

    expect(repository.items, hasLength(1));
    expect(duplicate.id, first.id);
    expect(first.type, AppointmentType.personal);
  });

  test('rejects an empty title before persistence', () async {
    final repository = _MemoryAppointmentRepository();
    final service = AppointmentLifecycleService(repository: repository);

    expect(
      () => service.create(
        title: '   ',
        startsAt: DateTime.now().add(const Duration(hours: 1)),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(repository.items, isEmpty);
  });

  test('allows updating a valid appointment through the application boundary', () async {
    final repository = _MemoryAppointmentRepository();
    final service = AppointmentLifecycleService(repository: repository);
    final created = await service.create(
      title: 'اجتماع الفريق',
      startsAt: DateTime.now().add(const Duration(days: 1)),
      type: AppointmentType.work,
    );
    final updated = created.copyWith(title: 'اجتماع الفريق الأسبوعي');

    await service.update(updated);

    expect(repository.items.single.title, 'اجتماع الفريق الأسبوعي');
  });
}
