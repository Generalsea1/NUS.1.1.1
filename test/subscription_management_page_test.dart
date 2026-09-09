import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/currency_registry.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/expenses/presentation/subscription_management_page.dart';
import 'package:nus/features/expenses/domain/expense.dart';

class _FakeExpenseRepo implements ExpenseRepository {
  @override
  Future<Expense?> getById(String id) async => null;
  @override
  Future<List<Expense>> list() async => const [];
  @override
  Future<void> save(Expense entity) async {}
  @override
  Future<void> deleteById(String id) async {}
}

class _FakeRecurringRepo implements RecurringExpenseRepository {
  _FakeRecurringRepo(this.items);
  List<RecurringExpenseDefinition> items;

  @override
  Future<RecurringExpenseDefinition?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<List<RecurringExpenseDefinition>> list() async => List.unmodifiable(items);

  @override
  Future<void> save(RecurringExpenseDefinition entity) async {
    items = [
      for (final item in items)
        if (item.id != entity.id) item,
      entity,
    ];
  }

  @override
  Future<void> deleteById(String id) async {
    items = items.where((item) => item.id != id).toList(growable: false);
  }

  @override
  Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) async {
    final item = await getById(id);
    if (item == null) throw StateError('missing');
    final updated = item.copyWith(enabled: enabled);
    await save(updated);
    return updated;
  }
}

RecurringExpenseDefinition _subscription({
  required String id,
  required String name,
  required String currency,
  required int minorUnits,
  String category = 'subscriptions',
  bool enabled = true,
}) => RecurringExpenseDefinition(
      id: id,
      userId: 'u1',
      name: name,
      amount: Money(minorUnits: minorUnits, currencyCode: currency),
      categoryCode: category,
      frequency: 'monthly',
      enabled: enabled,
      startDate: ExpenseDate(year: 2026, month: 1, day: 1),
    );

void main() {
  test('registry supports currency-specific subscription display precision', () {
    expect(CurrencyRegistry.get('EGP').exponent, 2);
    expect(CurrencyRegistry.get('JPY').exponent, 0);
  });

  testWidgets('shows subscriptions, filters by currency, and toggles state', (tester) async {
    final recurring = _FakeRecurringRepo([
      _subscription(id: 's1', name: 'Netflix', currency: 'EGP', minorUnits: 30000),
      _subscription(id: 's2', name: 'Salary unrelated', currency: 'EGP', minorUnits: 50000, category: 'housing'),
      _subscription(id: 's3', name: 'JPY Service', currency: 'JPY', minorUnits: 1200),
    ]);
    final service = ExpenseManagementService(
      expenseRepository: _FakeExpenseRepo(),
      recurringRepository: recurring,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SubscriptionManagementPage(
          userId: 'u1',
          currencyCode: 'EGP',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Salary unrelated'), findsNothing);
    expect(find.text('JPY Service'), findsNothing);
    expect(find.textContaining('300.00 EGP'), findsNWidgets(2));

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إيقاف مؤقت'));
    await tester.pumpAndSettle();

    final updated = await recurring.getById('s1');
    expect(updated?.enabled, isFalse);
  });
}
