import '../../appointments/domain/appointment.dart';
import '../../household/domain/household_task.dart';
import '../../obligations/domain/obligation.dart';
import '../domain/nus_work_item.dart';

class NusUnifiedWorkBuilder {
  const NusUnifiedWorkBuilder._();

  static List<NusWorkItem> build({
    required List<NusWorkReminderInput> reminders,
    required List<Appointment> appointments,
    required List<HouseholdTask> householdTasks,
    required List<Obligation> obligations,
  }) {
    final items = <NusWorkItem>[];

    for (final reminder in reminders) {
      items.add(
        NusWorkItem(
          id: 'reminder:${reminder.id}',
          title: reminder.title,
          kind: NusWorkItemKind.reminder,
          completed: reminder.completed,
          priority: NusWorkItemPriority.normal,
          dueAt: reminder.dueAt,
        ),
      );
    }

    for (final appointment in appointments) {
      items.add(
        NusWorkItem(
          id: 'appointment:${appointment.id}',
          title: appointment.title,
          kind: NusWorkItemKind.appointment,
          completed: appointment.status != AppointmentStatus.upcoming,
          priority: NusWorkItemPriority.high,
          dueAt: appointment.startsAt,
        ),
      );
    }

    for (final task in householdTasks) {
      items.add(
        NusWorkItem(
          id: 'household_task:${task.id}',
          title: task.title,
          kind: NusWorkItemKind.householdTask,
          completed: task.completed,
          priority: NusWorkItemPriority.normal,
          dueAt: task.dueAt,
        ),
      );
    }

    for (final obligation in obligations.where((item) => item.enabled)) {
      items.add(
        NusWorkItem(
          id: 'obligation:${obligation.id}',
          title: obligation.name,
          kind: NusWorkItemKind.obligation,
          completed: false,
          priority: NusWorkItemPriority.high,
          amountMinorUnits: obligation.amount,
          currencyCode: obligation.currencyCode,
        ),
      );
    }

    return NusWorkQueue.active(items);
  }
}

class NusWorkReminderInput {
  const NusWorkReminderInput({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.completed,
  });

  final String id;
  final String title;
  final DateTime dueAt;
  final bool completed;
}
