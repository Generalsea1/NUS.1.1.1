import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_type.dart';

class SupabaseExpenseRepository implements ExpenseRepository {
  const SupabaseExpenseRepository();

  static const _select =
      'id,user_id,amount_minor_units,currency_code,occurred_on,'
      'category_code,expense_type,merchant,description,payment_method,'
      'recurring_definition_id,obligation_id,created_at,updated_at';

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) throw const ExpenseConfigurationException();
    return client;
  }

  String _userId() {
    final id = SupabaseService.client?.auth.currentUser?.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Authenticated user is required.');
    }
    return id;
  }

  @override
  Future<List<Expense>> list() async {
    final rows = await _client()
        .from('expense_records')
        .select(_select)
        .eq('user_id', _userId())
        .order('occurred_on', ascending: false)
        .order('id', ascending: true);
    return rows
        .map((row) => Expense.fromJson(_fromRow(Map<String, dynamic>.from(row))))
        .toList(growable: false);
  }

  @override
  Future<Expense?> getById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Expense ID is required.');
    }
    final row = await _client()
        .from('expense_records')
        .select(_select)
        .eq('id', clean)
        .eq('user_id', _userId())
        .maybeSingle();
    return row == null
        ? null
        : Expense.fromJson(_fromRow(Map<String, dynamic>.from(row)));
  }

  @override
  Future<void> save(Expense entity) async {
    final userId = _userId();
    if (entity.userId.trim() != userId) {
      throw StateError('Expense ownership does not match the authenticated user.');
    }
    final category = entity.categoryCode;
    if (category == null || !ExpenseCategories.isSupported(category)) {
      throw ArgumentError.value(
        category,
        'categoryCode',
        'Authoritative expenses require a supported category.',
      );
    }

    final payload = _toRow(entity);
    final existing = await getById(entity.id);
    if (existing == null) {
      await _client().from('expense_records').insert(payload);
    } else {
      final update = Map<String, dynamic>.from(payload)
        ..remove('created_at');
      await _client()
          .from('expense_records')
          .update(update)
          .eq('id', entity.id)
          .eq('user_id', userId);
    }
  }

  @override
  Future<void> deleteById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Expense ID is required.');
    }
    await _client()
        .from('expense_records')
        .delete()
        .eq('id', clean)
        .eq('user_id', _userId());
  }

  Map<String, dynamic> _toRow(Expense expense) => <String, dynamic>{
        'id': expense.id,
        'user_id': expense.userId,
        'amount_minor_units': expense.amount.minorUnits,
        'currency_code': expense.amount.currencyCode,
        'occurred_on': expense.date.toIsoString(),
        'category_code': expense.categoryCode,
        'expense_type': expense.expenseType.code,
        'merchant': expense.merchant,
        'description': expense.description,
        'payment_method': expense.paymentMethod,
        'recurring_definition_id': expense.recurringDefinitionId,
        'obligation_id': expense.obligationId,
        'created_at': expense.createdAt.toUtc().toIso8601String(),
        'updated_at': expense.updatedAt.toUtc().toIso8601String(),
      };

  Map<String, dynamic> _fromRow(Map<String, dynamic> row) => <String, dynamic>{
        'id': row['id'],
        'userId': row['user_id'],
        'amountMinorUnits': row['amount_minor_units'],
        'currencyCode': row['currency_code'],
        'date': row['occurred_on'],
        'categoryCode': row['category_code'],
        'expenseType': row['expense_type'],
        'merchant': row['merchant'],
        'description': row['description'],
        'paymentMethod': row['payment_method'],
        'recurringDefinitionId': row['recurring_definition_id'],
        'obligationId': row['obligation_id'],
        'createdAt': row['created_at'],
        'updatedAt': row['updated_at'],
      };
}

class ExpenseConfigurationException implements Exception {
  const ExpenseConfigurationException();

  @override
  String toString() => 'Supabase expense storage is not configured for this build.';
}
