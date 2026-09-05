import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/finance/application/budget_query_service.dart';
import 'package:nus/features/finance/domain/budget.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

void main() {
  test('budget uses exact minor units and deterministic serialization', () {
    final budget = Budget(
      id: 'b1',
      name: 'Food',
      limitMinorUnits: 50000,
      currencyCode: 'usd',
      periodStart: DateTime(2026, 9, 1),
      periodEnd: DateTime(2026, 10, 1),
      categoryId: 'food',
    );
    expect(budget.currencyCode, 'USD');
    expect(budget.limitMinorUnits, 50000);
    expect(Budget.fromJson(budget.toJson()), budget);
    expect(budget.toJson()['limitMinorUnits'], isA<int>());
  });

  test('budget rejects invalid money, currency and period', () {
    expect(() => Budget(id: '', name: 'x', limitMinorUnits: 1, currencyCode: 'USD', periodStart: DateTime(2026), periodEnd: DateTime(2026, 1, 2)), throwsArgumentError);
    expect(() => Budget(id: 'b', name: 'x', limitMinorUnits: 0, currencyCode: 'USD', periodStart: DateTime(2026), periodEnd: DateTime(2026, 1, 2)), throwsArgumentError);
    expect(() => Budget(id: 'b', name: 'x', limitMinorUnits: 1, currencyCode: 'US', periodStart: DateTime(2026), periodEnd: DateTime(2026, 1, 2)), throwsArgumentError);
    expect(() => Budget(id: 'b', name: 'x', limitMinorUnits: 1, currencyCode: 'USD', periodStart: DateTime(2026, 9, 2), periodEnd: DateTime(2026, 9, 1)), throwsArgumentError);
  });

  test('expense budget derives positive consumption from negative ledger amounts', () async {
    final repo = FakeTxRepo([
      tx('1', -1000, DateTime(2026, 9, 5), 'food', 'USD'),
      tx('2', -2000, DateTime(2026, 9, 6), 'food', 'USD'),
      tx('3', -9000, DateTime(2026, 9, 7), 'other', 'USD'),
      tx('4', -7000, DateTime(2026, 9, 7), 'food', 'EUR'),
      tx('5', -5000, DateTime(2026, 10, 1), 'food', 'USD'),
    ]);
    final query = BudgetQueryService(transactions: repo);
    final budget = Budget(id: 'b', name: 'Food', limitMinorUnits: 2500, currencyCode: 'USD', periodStart: DateTime(2026, 9, 1), periodEnd: DateTime(2026, 10, 1), categoryId: 'food');
    expect(await query.consumedMinorUnits(budget), 3000);
    expect(await query.remainingMinorUnits(budget), -500);
    expect(await query.isExceeded(budget), isTrue);
  });

  test('income budget derives only positive compatible transactions', () async {
    final repo = FakeTxRepo([
      tx('1', 1000, DateTime(2026, 9, 5), 'salary', 'USD'),
      tx('2', -2000, DateTime(2026, 9, 6), 'salary', 'USD'),
      tx('3', 3000, DateTime(2026, 9, 7), 'salary', 'EUR'),
    ]);
    final query = BudgetQueryService(transactions: repo);
    final budget = Budget(id: 'b', name: 'Salary', limitMinorUnits: 5000, currencyCode: 'USD', periodStart: DateTime(2026, 9, 1), periodEnd: DateTime(2026, 10, 1), direction: BudgetDirection.income, categoryId: 'salary');
    expect(await query.consumedMinorUnits(budget), 1000);
    expect(await query.isExceeded(budget), isFalse);
  });
}

FinancialTransaction tx(String id, int amount, DateTime date, String category, String currency) => FinancialTransaction(id: id, accountId: 'a', amountMinorUnits: amount, currencyCode: currency, occurredOn: date, categoryId: category);

class FakeTxRepo implements FinancialTransactionRepository {
  FakeTxRepo(this.items);
  final List<FinancialTransaction> items;
  @override Future<void> deleteById(String id) async {}
  @override Future<FinancialTransaction?> getById(String id) async { for (final item in items) { if (item.id == id) return item; } return null; }
  @override Future<List<FinancialTransaction>> list() async => List.unmodifiable(items);
  @override Future<void> save(FinancialTransaction entity) async { items.removeWhere((x) => x.id == entity.id); items.add(entity); }
}
