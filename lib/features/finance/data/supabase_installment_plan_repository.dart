import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/installment_plan_repository.dart';
import '../domain/installment_plan.dart';

class SupabaseInstallmentPlanRepository implements InstallmentPlanRepository {
  const SupabaseInstallmentPlanRepository();

  static const _select = 'id,user_id,title,currency_code,total_minor_units,down_payment_minor_units,number_of_installments,paid_installments,first_due_date';

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) throw const InstallmentPlanConfigurationException();
    return client;
  }

  String _userId(String value) {
    final clean = value.trim();
    final current = SupabaseService.client?.auth.currentUser?.id.trim();
    if (clean.isEmpty || current == null || current.isEmpty || current != clean) {
      throw StateError('Authenticated user does not match the installment plan owner.');
    }
    return clean;
  }

  @override
  Future<List<InstallmentPlan>> list(String userId) async {
    final cleanUserId = _userId(userId);
    final rows = await _client()
        .from('installment_plans')
        .select(_select)
        .eq('user_id', cleanUserId)
        .order('first_due_date', ascending: true)
        .order('created_at', ascending: false);
    return rows.map((row) => InstallmentPlan.fromMap(Map<String, dynamic>.from(row))).toList(growable: false);
  }

  @override
  Future<InstallmentPlan> create(InstallmentPlan plan) async {
    final cleanUserId = _userId(plan.userId);
    final row = await _client()
        .from('installment_plans')
        .insert(plan.toMap(includeId: false))
        .select(_select)
        .single();
    final created = InstallmentPlan.fromMap(Map<String, dynamic>.from(row));
    if (created.userId != cleanUserId) throw StateError('Installment plan ownership did not match the authenticated user.');
    return created;
  }

  @override
  Future<InstallmentPlan> update(InstallmentPlan plan) async {
    final cleanUserId = _userId(plan.userId);
    final payload = plan.toMap(includeId: false);
    final row = await _client()
        .from('installment_plans')
        .update(payload)
        .eq('id', plan.id.trim())
        .eq('user_id', cleanUserId)
        .select(_select)
        .maybeSingle();
    if (row == null) throw StateError('Installment plan was not found or could not be updated.');
    return InstallmentPlan.fromMap(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> delete(String userId, String planId) async {
    await _client()
        .from('installment_plans')
        .delete()
        .eq('id', planId.trim())
        .eq('user_id', _userId(userId));
  }
}

class InstallmentPlanConfigurationException implements Exception {
  const InstallmentPlanConfigurationException();
  @override
  String toString() => 'Supabase installment plan storage is not configured for this build.';
}
