import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../domain/expense.dart';
import '../domain/expense_category.dart';
import '../domain/expense_type.dart';

class SupabaseExpenseRepository implements ExpenseRepository {
  const SupabaseExpenseRepository();

  static const _select = 'id,user_id,amount_minor_units,currency_code,occurred_on,category_code,expense_type,merchant,description,payment_method,recurring_definition_id,obligation_id,created_at,updated_at';

  @override
  Future<List<Expense>> list() async {
    final client = _clientOrThrow();
    final userId = _currentUserId();
    final rows = await client
        .from('expense_records')
        .select(_select)
        .eq('user_id', userId)
        .order('occurred_on', ascending: false)
        .order('id', ascending: true);
    return rows.map((row) => Expense.fromMap(_fromRow(Map<String, dynamic>.from(row)))).toList(growable: false);
  }

  @override
  Future<Expense?> getById(String id) async {
    final client = _clientOrThrow();
    final row = await client.from('expense_records').select(_select).eq('id', _requireId(id)).eq('user_id', _currentUserId()).maybeSingle();
    return row == null ? null : Expense.fromMap(_fromRow(Map<String, dynamic>.from(row)));
  }

  @override
  Future<void> save(Expense entity) async {
    final client = _clientOrThrow();
    final userId = _currentUserId();
    if (entity.userId.trim() != userId) {
      throw StateError('Expense ownership does not match the authenticated user.');
    }
    if (entity.categoryCode == null || !ExpenseCategories.isSupported(entity.categoryCode!)) {
      throw ArgumentError.value(entity.categoryCode, 'categoryCode', 'Authoritative expenses require a supported category.');
    }
    final payload = _toRow(entity);
    final existing = await getById(entity.id);
    if (existing == null) {
      await client.from('expense_records').insert(payload).select(_select).single();
    } else {
      await client.from('expense_records').update(payload..remove('created_at')).eq('id', entity.id).eq('user_id', userId).select(_select).single();
    }
  }

  @override
  Future<void> deleteById(String id) async {
    await _clientOrThrow().from('expense_records').delete().eq('id', _requireId(id)).eq('user_id', _currentUserId());
  }

  SupabaseClient _clientOrThrow() {
    final client = SupabaseService.client;
    if (client == null) throw const ExpenseConfigurationException();
    return client;
  }

  String _currentUserId() {
    final userId = SupabaseService.client?.auth.currentUser?.id;
    if (userId == null || userId.trim().isEmpty) throw StateError('Authenticated user is required.');
    return userId;
  }

  String _requireId(String id) {
    final clean = id.trim();
    if (clean.isEmpty) throw ArgumentError.value(id, 'id', 'Expense ID is required.');
    return clean;
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