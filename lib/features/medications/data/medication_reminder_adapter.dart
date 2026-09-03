import '../../../notification_service.dart';
import '../domain/medication_reminder_port.dart';

class MedicationReminderAdapter implements MedicationReminderPort {
  const MedicationReminderAdapter(this.scheduler);

  final ReminderScheduler scheduler;

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required DateTime dateTime,
  }) =>
      scheduler.scheduleReminder(id: id, title: title, dateTime: dateTime);

  @override
  Future<void> cancel(String id) => scheduler.cancelReminder(id);
}
