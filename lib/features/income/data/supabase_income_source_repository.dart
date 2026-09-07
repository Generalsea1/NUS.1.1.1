import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/income_source_repository.dart';
import '../domain/income_source.dart';

class SupabaseIncomeSourceRepository implements IncomeSourceRepository {
  const SupabaseIncomeSourceRepository();

  static const _select = 'id,user_id,name,source_type,amount,currency_code,frequency,enabled,created_at,updated_at';

  @override
  Future<List<IncomeSource>> list(String userId) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(userId);
    final rows = await client
        .from('income_sources')
        .select(_select)
        .eq('user_id', cleanUserId)
        .order('created_at', ascending: true);
    return rows
        .map((row) => IncomeSource.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<IncomeSource> create(IncomeSource source) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(source.userId);
    final row = await client
        .from('income_sources')
        .insert(source.toMap(includeId: false))
        .select(_select)
        .single();
    final created = IncomeSource.fromMap(Map<String, dynamic>.from(row));
    if (created.userId != cleanUserId) {
      throw StateError('Income source ownership did not match the authenticated user.');
    }
    return created;
  }

  @override
  Future<IncomeSource> update(IncomeSource source) async {
    final client = _clientOrThrow();
    final sourceId = _requireSourceId(source.id);
    final cleanUserId = _requireUserId(source.userId);
    final row = await client
        .from('income_sources')
        .update(source.toMap(includeId: false)..remove('created_at'))
        .eq('id', sourceId)
        .eq('user_id', cleanUserId)
        .select(_select)
        .maybeSingle();
    if (row == null) throw StateError('Income source was not found or could not be updated.');
    return IncomeSource.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String userId, String sourceId) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(userId);
    final cleanSourceId = _requireSourceId(sourceId);
    await client
        .from('income_sources')
        .delete()
        .eq('id', cleanSourceId)
        .eq('user_id', cleanUserId);
  }

  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(userId);
    final cleanSourceId = _requireSourceId(sourceId);
    final row = await client
        .from('income_sources')
        .update({'enabled': enabled})
        .eq('id', cleanSourceId)
        .eq('user_id', cleanUserId)
        .select(_select)
        .maybeSingle();
    if (row == null) throw StateError('Income source was not found or could not be changed.');
    return IncomeSource.fromMap(Map<String, dynamic>.from(row));
  }

  SupabaseClient _clientOrThrow() {
    final client = SupabaseService.client;
    if (client == null) throw const IncomeSourceConfigurationException();
    return client;
  }

  String _requireUserId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) throw StateError('Authenticated user is required.');
    return clean;
  }

  String _requireSourceId(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) throw StateError('Income source ID is required.');
    return clean;
  }
}

class IncomeSourceConfigurationException implements Exception {
  const IncomeSourceConfigurationException();

  @override
  String toString() => 'Supabase income source storage is not configured for this build.';
}
