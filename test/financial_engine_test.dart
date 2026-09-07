import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/domain/income_source.dart';
import 'package:nus/features/obligations/application/obligation_repository.dart';
import 'package:nus/features/obligations/application/obligation_service.dart';
import 'package:nus/features/obligations/domain/obligation.dart';

class _IncomeRepo implements IncomeSourceRepository {
  _IncomeRepo(this.sources);
  final List<IncomeSource> sources;

  @override Future<List<IncomeSource>> list(String userId) async => sources.where((s) => s.userId == userId).toList();
  @override Future<IncomeSource> create(IncomeSource source) => throw UnimplementedError();
  @override Future<IncomeSource> update(IncomeSource source) => throw UnimplementedError();
  @override Future<void> delete(String userId, String sourceId) => throw UnimplementedError();
  @override Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) => throw UnimplementedError();
}

class _ObligationRepo implements ObligationRepository {
  _ObligationRepo(this.obligations);
  final List<Obligation> obligations;

  @override Future<List<Obligation>> list(String userId) async => obligations.where((o) => o.userId == userId).toList();
  @override Future<Obligation> create(Obligation obligation) => throw UnimplementedError();
  @override Future<Obligation> update(Obligation obligation) => throw UnimplementedError();
  @override Future<void> delete(String userId, String obligationId) => throw UnimplementedError();
  @override Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) => throw UnimplementedError();
}

class _ExpenseRepo implements ExpenseRepository {
  _ExpenseRepo(this.expenses);
  final List<Expense> expenses;
  @override Future<Expense?> getById(String id) async => _firstOrNull(expenses.where((e) => e.id == id));
  @override Future<List<Expense>> list() async => List<Expense>.of(expenses);
  @override Future<void> save(Expense entity) => throw UnimplementedError();
  @override Future<void> deleteById(String id) => throw UnimplementedError();
}

class _RecurringRepo implements RecurringExpenseRepository {
  _RecurringRepo(this.definitions);
  final List<RecurringExpenseDefinition> definitions;
  @override Future<RecurringExpenseDefinition?> getById(String id) async => _firstOrNull(definitions.where((d) => d.id == id));
  @override Future<List<RecurringExpenseDefinition>> list() async => List<RecurringExpenseDefinition>.of(definitions);
  @override Future<void> save(RecurringExpenseDefinition entity) => throw UnimplementedError();
  @override Future<void> deleteById(String id) => throw UnimplementedError();
  @override Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) => throw UnimplementedError();
}

IncomeSource _income({required String id, required int amount, bool enabled = true}) => IncomeSource(
      id: id, userId: 'u1', name: id, sourceType: 'salary', amount: amount,
      currencyCode: 'EGP', frequency: 'monthly', enabled: enabled,
      createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1));

Obligation _obligation({required String id, required int amount, bool enabled = true}) => Obligation(
      id: id, userId: 'u1', name: id, type: 'rent', amount: amount,
      currencyCode: 'EGP', frequency: 'monthly', enabled: enabled,
      createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1));

Expense _expense({required String id, required int minorUnits}) => Expense(
      id: id,
      userId: 'u1',
      amount: Money(minorUnits: minorUnits, currencyCode: 'EGP'),
      date: ExpenseDate(year: 2026, month: 9, day: 10),
      categoryCode: 'food');

RecurringExpenseDefinition _recurring({required String id, required int minorUnits}) => RecurringExpenseDefinition(
      id: id,
      userId: 'u1',
      name: id,
      amount: Money(minorUnits: minorUnits, currencyCode: 'EGP'),
      categoryCode: 'food',
      frequency: 'monthly',
      enabled: true,
      startDate: ExpenseDate(year: 2026, month: 1, day: 1));

void main() {
  test('aggregates authorities and keeps actual and committed positions separate', () async {
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(repository: _IncomeRepo([
        _income(id: 'salary', amount: 10000),
        _income(id: 'disabled', amount: 5000, enabled: false),
      ])),
      obligationService: ObligationService(repository: _ObligationRepo([
        _obligation(id: 'rent', amount: 3000),
        _obligation(id: 'disabled', amount: 7000, enabled: false),
      ])),
      expenseService: ExpenseManagementService(
        expenseRepository: _ExpenseRepo([_expense(id: 'food', minorUnits: 125000)]),
        recurringRepository: _RecurringRepo([_recurring(id: 'recurring-food', minorUnits: 25000)]),
      ),
    );

    final snapshot = await engine.calculate(
      userId: 'u1', year: 2026, month: 9, currencyCode: 'egp');

    expect(snapshot.monthlyIncome, 10000);
    expect(snapshot.monthlyObligations, 3000);
    expect(snapshot.actualExpensesMinorUnits, 125000);
    expect(snapshot.expectedRecurringExpensesMinorUnits, 25000);
    expect(snapshot.positionAfterObligations, 7000);
    expect(snapshot.actualPositionMinorUnits, 875000);
    expect(snapshot.monthlyIncomeMinorUnits, 1000000);
    expect(snapshot.monthlyObligationsMinorUnits, 300000);
  });

  test('does not combine obligations with actual payments into one position', () async {
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(repository: _IncomeRepo([_income(id: 'salary', amount: 10000)])),
      obligationService: ObligationService(repository: _ObligationRepo([_obligation(id: 'rent', amount: 3000)])),
      expenseService: ExpenseManagementService(
        expenseRepository: _ExpenseRepo([_expense(id: 'rent-payment', minorUnits: 300000)]),
        recurringRepository: _RecurringRepo([]),
      ),
    );

    final snapshot = await engine.calculate(
      userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');

    expect(snapshot.positionAfterObligations, 7000);
    expect(snapshot.actualPositionMinorUnits, 700000);
  });

  test('currency is isolated and invalid currency is rejected', () async {
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(repository: _IncomeRepo([_income(id: 'salary', amount: 10000)])),
      obligationService: ObligationService(repository: _ObligationRepo([])),
      expenseService: ExpenseManagementService(
        expenseRepository: _ExpenseRepo([]),
        recurringRepository: _RecurringRepo([]),
      ),
    );
    expect(
      (await engine.calculate(userId: 'u1', year: 2026, month: 9, currencyCode: 'USD')).monthlyIncome,
      0,
    );
    await expectLater(
      engine.calculate(userId: 'u1', year: 2026, month: 9, currencyCode: 'ZZZ'),
      throwsA(isA<ArgumentError>()),
    );
  });
}

T? _firstOrNull<T>(Iterable<T> values) => values.isEmpty ? null : values.first;
