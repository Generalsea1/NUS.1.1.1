import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/household/domain/household_task.dart';
import 'package:nus/features/obligations/domain/obligation.dart';
import 'package:nus/features/today/application/nus_unified_work_builder.dart';
import 'package:nus/features/today/domain/nus_work_item.dart';

void main() {
  test('combines reminders, appointments, household tasks and enabled obligations', () {
    final now = DateTime.now();
    final items = NusUnifiedWorkBuilder.build(
      reminders: [
        legacyWorkReminder(
          id: 'r1',
          title: 'Call school',
          dueAt: now.add(const Duration(hours: 1)),
          completed: false,
        ),
      ],
      appointments: [
        Appointment(
          id: 'a1',
          title: 'Doctor',
          startsAt: now.add(const Duration(hours: 2)),
          status: AppointmentStatus.upcoming,
        ),
      ],
      householdTasks: [
        HouseholdTask(
          id: 't1',
          householdId: 'h1',
          createdBy: 'u1',
          title: 'Buy water',
          completed: false,
          dueAt: now.add(const Duration(hours: 3)),
          createdAt: now,
          updatedAt: now,
        ),
      ],
      obligations: [
        Obligation(
          id: 'o1',
          userId: 'u1',
          name: 'Rent',
          type: 'rent',
          amount: 10000,
          currencyCode: 'EGP',
          frequency: 'monthly',
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
        Obligation(
          id: 'o2',
          userId: 'u1',
          name: 'Disabled',
          type: 'other',
          amount: 1,
          currencyCode: 'EGP',
          frequency: 'monthly',
          enabled: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    expect(items.map((item) => item.id), containsAllInOrder([
      'reminder:r1',
      'appointment:a1',
      'household_task:t1',
      'obligation:o1',
    ]));
    expect(items.where((item) => item.id == 'obligation:o2'), isEmpty);
  });

  test('keeps completed sources out of the active queue', () {
    final now = DateTime.now();
    final items = NusUnifiedWorkBuilder.build(
      reminders: [
        legacyWorkReminder(
          id: 'done',
          title: 'Done',
          dueAt: now.subtract(const Duration(minutes: 5)),
          completed: true,
        ),
      ],
      appointments: [
        Appointment(
          id: 'done-appointment',
          title: 'Done appointment',
          startsAt: now.subtract(const Duration(hours: 1)),
          status: AppointmentStatus.completed,
        ),
      ],
      householdTasks: const [],
      obligations: const [],
    );

    expect(items, isEmpty);
  });
}
