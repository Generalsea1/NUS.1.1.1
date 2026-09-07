import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Slice 4 has exactly one migration with both authoritative tables and RLS', () {
    final files = Directory('docs/sql')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();
    final slice4 = files.where((name) => name.contains('expense_management')).toList();
    expect(slice4, hasLength(1));
    final sql = File('docs/sql/${slice4.single}').readAsStringSync();
    expect(sql, contains('create table if not exists public.recurring_expense_definitions'));
    expect(sql, contains('create table if not exists public.expense_records'));
    expect(sql, contains('amount_minor_units bigint not null check (amount_minor_units > 0)'));
    expect(sql, contains('auth.uid() = user_id'));
    expect(sql, contains('expense_records_user_occurred_idx'));
    expect(sql, contains('recurring_expense_user_enabled_idx'));
    expect(sql, contains("expense_type in ('one_time','variable','recurring')"));
    expect(sql, contains("(expense_type = 'recurring' and recurring_definition_id is not null)"));
    expect(sql, contains("(expense_type <> 'recurring' and recurring_definition_id is null)"));
    expect(sql, contains('on delete restrict'));
    expect(sql, isNot(contains('float')));
    expect(sql, isNot(contains('double precision')));
  });
}
