import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/household_task_repository.dart';
import '../domain/household_task.dart';

class SupabaseHouseholdTaskRepository implements HouseholdTaskRepository {
  const SupabaseHouseholdTaskRepository();

  static const _select = 'id,household_id,created_by,title,due_at,completed,completed_at,created_at,updated_at';

  @override
  Future<List<HouseholdTask>> list(String householdId) async {
    final clean = _required(householdId, 'householdId');
    final rows = await _client()
        .from('household_tasks')
        .select(_select)
        .eq('household_id', clean)
        .order('completed', ascending: true)
        .order('due_at', ascending: true)
        .order('created_at', ascending: true);
    return rows
        .map((row) => HouseholdTask.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<HouseholdTask> create(HouseholdTask task) async {
    _requireCurrentUser(task.createdBy);
    final row = await _client()
        .from('household_tasks')
        .insert(task.toMap(includeId: false))
        .select(_select)
        .single();
    return HouseholdTask.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<HouseholdTask> update(HouseholdTask task) async {
    final currentUserId = _currentUserId;
    final row = await _client()
        .from('household_tasks')
        .update({
          'title': task.title,
          'due_at': task.dueAt?.toUtc().toIso8601String(),
          'completed': task.completed,
          'completed_at': task.completedAt?.toUtc().toIso8601String(),
        })
        .eq('id', _required(task.id, 'id'))
        .eq('household_id', _required(task.householdId, 'householdId'))
        .select(_select)
        .maybeSingle();
    if (row == null) throw StateError('Shared task was not found or could not be updated.');
    if (currentUserId == null) throw StateError('Authenticated user is required.');
    return HouseholdTask.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String householdId, String taskId) async {
    await _client()
        .from('household_tasks')
        .delete()
        .eq('household_id', _required(householdId, 'householdId'))
        .eq('id', _required(taskId, 'taskId'));
  }

  SupabaseClient _client() => SupabaseService.client ?? (throw const HouseholdTaskConfigurationException());

  String? get _currentUserId => SupabaseService.client?.auth.currentUser?.id.trim();

  void _requireCurrentUser(String userId) {
    final current = _currentUserId;
    final clean = _required(userId, 'createdBy');
    if (current == null || current.isEmpty || current != clean) {
      throw StateError('Authenticated user does not match the task creator.');
    }
  }

  String _required(String value, String field) {
    final clean = value.trim();
    if (clean.isEmpty) throw ArgumentError.value(value, field, '$field is required.');
    return clean;
  }
}

class HouseholdTaskConfigurationException implements Exception {
  const HouseholdTaskConfigurationException();

  @override
  String toString() => 'Supabase shared task storage is not configured for this build.';
}
