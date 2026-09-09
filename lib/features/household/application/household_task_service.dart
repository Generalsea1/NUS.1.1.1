import '../domain/household_task.dart';
import 'household_task_repository.dart';

class HouseholdTaskService {
  HouseholdTaskService({required HouseholdTaskRepository repository}) : _repository = repository;

  final HouseholdTaskRepository _repository;

  Future<List<HouseholdTask>> list(String householdId) async {
    final cleanHouseholdId = _required(householdId, 'householdId');
    final tasks = await _repository.list(cleanHouseholdId);
    return List<HouseholdTask>.unmodifiable(tasks);
  }

  Future<HouseholdTask> create({
    required String householdId,
    required String createdBy,
    required String title,
    DateTime? dueAt,
  }) {
    final cleanHouseholdId = _required(householdId, 'householdId');
    final cleanCreatedBy = _required(createdBy, 'createdBy');
    return _repository.create(
      HouseholdTask(
        id: _localId(),
        householdId: cleanHouseholdId,
        createdBy: cleanCreatedBy,
        title: title,
        completed: false,
        dueAt: dueAt,
      ),
    );
  }

  Future<HouseholdTask> setCompleted(HouseholdTask task, bool completed) {
    return _repository.update(task.copyWith(completed: completed));
  }

  Future<HouseholdTask> rename(HouseholdTask task, String title) {
    return _repository.update(task.copyWith(title: title));
  }

  Future<void> delete(HouseholdTask task) => _repository.delete(task.householdId, task.id);

  String _required(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty) throw ArgumentError.value(value, field, '$field is required.');
    return clean;
  }

  String _localId() => DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}
