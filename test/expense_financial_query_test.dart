import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/finance/application/expense_financial_query_service.dart';
import 'package:nus/features/finance/data/expense_repository_financial_reader.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  _FakeExpenseRepository(this._expenses);

  final List<Expense> _expenses;

  @override
  Future<Expense?> getById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<List<Expense>> list() async => List<Expense>.of(_expenses);

  @override
  Future<void> save(Expense entity) async => throw UnimplementedError();

  @override
  Future<void> deleteById(String id) async => throw UnimplementedError();
}

Expense _expense({
  required String id,
  required int minorUnits,
  required String currencyCode,
  required int year,
  required int month,
  required int day,
  String? category,
}) => Expense(
      id: id,
      amount: Money(minorUnits: minorUnits, currencyCode: currencyCode),
      date: ExpenseDate(year: year, month: month, day: day),
      category: category,
    );

void main() {
  test('projects Expense records and totals one month by currency', () async {
    final reader = ExpenseRepositoryFinancialReader(
      repository: _FakeExpenseRepository([
        _expense(
          id: 'a',
          minorUnits: 1000,
          currencyCode: 'usd',
          year: 2026,
          month: 9,
          day: 1,
          category: 'Food',
        ),
        _expense(
          id: 'b',
          minorUnits: 2500,
          currencyCode: 'USD',
          year: 2026,
          month: 9,
          day: 2,
          category: 'Bills',
        ),
        _expense(
          id: 'c',
          minorUnits: 999,
          currencyCode: 'EUR',
          year: 2026,
          month: 9,
          day: 3,
          category: 'Food',
        ),
        _expense(
          id: 'd',
          minorUnits: 500,
          currencyCode: 'USD',
          year: 2026,
          month: 8,
          day: 31,
          category: 'Food',
        ),
      ]),
    );
    final service = ExpenseFinancialQueryService(reader: reader);

    expect(
      await service.monthlyExpenseMinorUnits(
        year: 2026,
        month: 9,
        currencyCode: 'usd',
      ),
      3500,
    );

    expect(
      await service.monthlyExpenseMinorUnitsByCategory(
        year: 2026,
        month: 9,
        currencyCode: 'USD',
      ),
      {'Bills': 2500, 'Food': 1000},
    );
  });

  test('financial snapshot preserves current Expense category representation', () async {
    final reader = ExpenseRepositoryFinancialReader(
      repository: _FakeExpenseRepository([
        _expense(
          id: 'expense-1',
          minorUnits: 1200,
          currencyCode: 'USD',
          year: 2026,
          month: 9,
          day: 4,
          category: 'Food',
        ),
      ]),
    );

    final snapshot = (await reader.readExpenses()).single;
    expect(snapshot.id, 'expense-1');
    expect(snapshot.amountMinorUnits, 1200);
    expect(snapshot.currencyCode, 'USD');
    expect(snapshot.category, 'Food');
    expect(snapshot.year, 2026);
    expect(snapshot.month, 9);
    expect(snapshot.day, 4);
  });

  test('Expense totals are represented as negative cash-flow deltas', () {
    final service = _SignedExpenseProbe();
    expect(service.signedExpenseMinorUnits(1234), -1234);
  });
}

class _SignedExpenseProbe extends ExpenseFinancialQueryService {
  const _SignedExpenseProbe() : super(reader: _EmptyReader());
}

class _EmptyReader implements FinancialExpenseReader {
  const _EmptyReader();

  @override
  Future<List<FinancialExpenseSnapshot>> readExpenses() async =>
      const <FinancialExpenseSnapshot>[];
}
