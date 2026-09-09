import '../domain/household_task.dart';

abstract interface class HouseholdTaskRepository {
  Future<List<HouseholdTask>> list(String householdId);
  Future<HouseholdTask> create(HouseholdTask task);
  Future<HouseholdTask> update(HouseholdTask task);
  Future<void> delete(String householdId, String taskId);
}
