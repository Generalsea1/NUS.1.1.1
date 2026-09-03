import '../domain/medication.dart';
import 'medication_reminder_coordinator.dart';

class MedicationLifecycleService {
  const MedicationLifecycleService({
    required this.repository,
    required this.reminders,
  });

  final MedicationRepository repository;
  final MedicationReminderCoordinator reminders;

  Future<void> save(Medication medication, {Medication? previous}) async {
    await repository.save(medication);
    await reminders.sync(medication, previous: previous);
  }

  Future<void> setActive(Medication medication, bool isActive) async {
    final updated = medication.copyWith(isActive: isActive);
    await save(updated, previous: medication);
  }

  Future<void> delete(Medication medication) async {
    await reminders.cancel(medication);
    await repository.deleteById(medication.id);
  }

  Future<List<Medication>> list() => repository.list();
}
