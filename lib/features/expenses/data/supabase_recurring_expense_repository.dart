import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../domain/recurring_expense_definition.dart';

class SupabaseRecurringExpenseRepository implements RecurringExpenseRepository {
  const SupabaseRecurringExpenseRepository();

  static const _select = 'id,user_id,name,amount_minor_units,currency_code,category_code,frequency,enabled,start_date,end_date,created_at,updated_at';

  @override
  Future<List<RecurringExpenseDefinition>> list() async {
    final rows = await _client().from('recurring_expense_definitions').select(_select).eq('user_id', _userId()).order('start_date', ascending: true).order('id', ascending: true);
    return rows.map((row) => RecurringExpenseDefinition.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  @override
  Future<RecurringExpenseDefinition?> getById(String id) async {
    final row = await _client().from('recurring_expense_definitions').select(_select).eq('id', _requireId(id)).eq('user_id', _userId()).maybeSingle();
    return row == null ? null : RecurringExpenseDefinition.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> save(RecurringExpenseDefinition entity) async {
    final userId = _userId();
    if (entity.userId != userId) throw StateError('Recurring expense ownership does not match the authenticated user.');
    final payload = entity.toMap();
    final existing = await getById(entity.id);
    if (existing == null) {
      await _client().from('recurring_expense_definitions').insert(payload).select(_select).single();
    } else {
      await _client().from('recurring_expense_definitions').update(payload..remove('created_at')).eq('id', entity.id).eq('user_id', userId).select(_select).single();
    }
  }

  @override
  Future<void> deleteById(String id) async {
    await _client().from('recurring_expense_definitions').delete().eq('id', _requireId(id)).eq('user_id', _userId());
  }

  @override
  Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) async {
    final authenticated = _userId();
    if (userId.trim() != authenticated) throw StateError('Recurring expense ownership does not match the authenticated user.');
    final row = await _client().from('recurring_expense_definitions').update({'enabled': enabled}).eq('id', _requireId(id)).eq('user_id', authenticated).select(_select).maybeSingle();
    if (row == null) throw StateError('Recurring expense was not found or could not be changed.');
    return RecurringExpenseDefinition.fromMap(Map<String, dynamic>.from(row));
  }

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) throw const RecurringExpenseConfigurationException();
    return client;
  }

  String _userId() {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) throw StateError('Authenticated user is required.');
    return userId;
  }

  String _requireId(String id) {
    final clean = id.trim();
    if (clean.isEmpty) throw ArgumentError.value(id, 'id', 'Recurring expense ID is required.');
    return clean;
  }
}

class RecurringExpenseConfigurationException implements Exception {
  const RecurringExpenseConfigurationException();
  @override
  String toString() => 'Supabase recurring expense storage is not configured for this build.';
}