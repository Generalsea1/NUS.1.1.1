import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/obligation_repository.dart';
import '../domain/obligation.dart';

class SupabaseObligationRepository implements ObligationRepository {
  const SupabaseObligationRepository();
  static const _select = 'id,user_id,name,type,amount,currency_code,frequency,enabled,created_at,updated_at';

  @override
  Future<List<Obligation>> list(String userId) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(userId);
    final rows = await client.from('obligations').select(_select).eq('user_id', cleanUserId).order('created_at', ascending: true);
    return rows.map((row) => Obligation.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  @override
  Future<Obligation> create(Obligation obligation) async {
    final client = _clientOrThrow();
    final cleanUserId = _requireUserId(obligation.userId);
    final row = await client.from('obligations').insert(obligation.toMap(includeId: false)).select(_select).single();
    final created = Obligation.fromMap(Map<String, dynamic>.from(row));
    if (created.userId != cleanUserId) throw StateError('Obligation ownership did not match the authenticated user.');
    return created;
  }

  @override
  Future<Obligation> update(Obligation obligation) async {
    final client = _clientOrThrow();
    final id = _requireId(obligation.id);
    final cleanUserId = _requireUserId(obligation.userId);
    final payload = obligation.toMap(includeId: false)..remove('created_at');
    final row = await client.from('obligations').update(payload).eq('id', id).eq('user_id', cleanUserId).select(_select).maybeSingle();
    if (row == null) throw StateError('Obligation was not found or could not be updated.');
    return Obligation.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String userId, String obligationId) async {
    final client = _clientOrThrow();
    await client.from('obligations').delete().eq('id', _requireId(obligationId)).eq('user_id', _requireUserId(userId));
  }

  @override
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) async {
    final client = _clientOrThrow();
    final row = await client.from('obligations').update({'enabled': enabled}).eq('id', _requireId(obligationId)).eq('user_id', _requireUserId(userId)).select(_select).maybeSingle();
    if (row == null) throw StateError('Obligation was not found or could not be changed.');
    return Obligation.fromMap(Map<String, dynamic>.from(row));
  }

  SupabaseClient _clientOrThrow() {
    final client = SupabaseService.client;
    if (client == null) throw const ObligationConfigurationException();
    return client;
  }

  String _requireUserId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) throw StateError('Authenticated user is required.');
    return clean;
  }

  String _requireId(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) throw StateError('Obligation ID is required.');
    return clean;
  }
}

class ObligationConfigurationException implements Exception {
  const ObligationConfigurationException();
  @override
  String toString() => 'Supabase obligation storage is not configured for this build.';
}
