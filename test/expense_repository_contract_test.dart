import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('authoritative repositories bind operations to authenticated ownership', () {
    final expense = File('lib/features/expenses/data/supabase_expense_repository.dart').readAsStringSync();
    final recurring = File('lib/features/expenses/data/supabase_recurring_expense_repository.dart').readAsStringSync();
    expect(expense, contains('auth.currentUser?.id'));
    expect(expense, contains(".eq('user_id', userId)"));
    expect(expense, contains('ownership does not match'));
    expect(recurring, contains('auth.currentUser?.id'));
    expect(recurring, contains(".eq('user_id', _userId())"));
    expect(recurring, contains('ownership does not match'));
  });
}
