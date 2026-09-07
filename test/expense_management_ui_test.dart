import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/expenses/presentation/expense_management_page.dart';

class _ExpenseRepo implements ExpenseRepository {
  _ExpenseRepo([List<Expense>? initial]) : items = List<Expense>.of(initial ?? const []);
  final List<Expense> items;

  @override
  Future<Expense?> getById(String id) async {
    for (final expense in items) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<List<Expense>> list() async => List<Expense>.of(items);

  @override
  Future<void> save(Expense expense) async {
    items.removeWhere((item) => item.id == expense.id);
    items.add(expense);
  }

  @override
  Future<void> deleteById(String id) async {
    items.removeWhere((expense) => expense.id == id);
  }
}

class _RecurringRepo implements RecurringExpenseRepository {
  @override
  Future<RecurringExpenseDefinition?> getById(String id) async => null;

  @override
  Future<List<RecurringExpenseDefinition>> list() async => const [];

  @override
  Future<void> save(RecurringExpenseDefinition expense) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<RecurringExpenseDefinition> setEnabled(
    String userId,
    String id,
    bool enabled,
  ) async => throw UnimplementedError();
}

void main() {
  testWidgets(
    'expense management separates actual and recurring views',
    (tester) async {
      final service = ExpenseManagementService(
        expenseRepository: _ExpenseRepo([
          Expense(
            id: 'e1',
            userId: 'u',
            amount: Money(minorUnits: 12500, currencyCode: 'EGP'),
            date: ExpenseDate(year: 2026, month: 9, day: 7),
            categoryCode: 'food',
          ),
        ]),
        recurringRepository: _RecurringRepo(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseManagementPage(
            service: service,
            householdCurrencyCode: 'EGP',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مصروفات مدير المنزل'), findsOneWidget);
      expect(find.text('فعلي'), findsOneWidget);
      expect(find.text('متوقع متكرر'), findsOneWidget);
      expect(find.text('المتكررة'), findsOneWidget);

      await tester.tap(find.text('المتكررة'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'المتكرر هنا توقع فقط. تعريف متكرر لا ينشئ مصروفًا فعليًا تلقائيًا.',
        ),
        findsOneWidget,
      );
    },
  );
}
