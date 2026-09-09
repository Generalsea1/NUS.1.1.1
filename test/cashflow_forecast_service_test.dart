import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/expense_type.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/finance/application/cashflow_forecast_service.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/domain/income_source.dart';
import 'package:nus/features/obligations/application/obligation_repository.dart';
import 'package:nus/features/obligations/application/obligation_service.dart';
import 'package:nus/features/obligations/domain/obligation.dart';

class _IncomeRepo implements IncomeSourceRepository {
  _IncomeRepo(this.source);
  final IncomeSource source;

  @override
  Future<List<IncomeSource>> list(String userId) async => [source];

  @override
  Future<IncomeSource> create(IncomeSource source) async => source;

  @override
  Future<IncomeSource> update(IncomeSource source) async => source;

  @override
  Future<void> delete(String userId, String sourceId) async {}

  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async =>
      source.copyWith(enabled: enabled);
}

class _ObligationRepo implements ObligationRepository {
  @override
  Future<List<Obligation>> list(String userId) async => const [];

  @override
  Future<Obligation> create(Obligation obligation) async => obligation;

  @override
  Future<Obligation> update(Obligation obligation) async => obligation;

  @override
  Future<void> delete(String userId, String obligationId) async {}

  @override
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) async =>
      throw UnimplementedError();
}

class _ExpenseRepo implements ExpenseRepository {
  _ExpenseRepo(this.items);
  final List<Expense> items;

  @override
  Future<Expense?> getById(String id) async =>
      items.where((item) => item.id == id).firstOrNull;

  @override
  Future<List<Expense>> list() async => List<Expense>.of(items);

  @override
  Future<void> save(Expense expense) async {
    items.removeWhere((item) => item.id == expense.id);
    items.add(expense);
  }

  @override
  Future<void> deleteById(String id) async => items.removeWhere((item) => item.id == id);
}

class _RecurringRepo implements RecurringExpenseRepository {
  @override
  Future<RecurringExpenseDefinition?> getById(String id) async => null;

  @override
  Future<List<RecurringExpenseDefinition>> list() async => const [];

  @override
  Future<void> save(RecurringExpenseDefinition entity) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<RecurringExpenseDefinition> setEnabled(
    String userId,
    String id,
    bool enabled,
  ) async => throw UnimplementedError();
}

Expense _expense(String id, int month, int minor) => Expense(
      id: id,
      userId: 'user-1',
      amount: Money(minorUnits: minor, currencyCode: 'EGP'),
      date: ExpenseDate(year: 2026, month: month, day: 10),
      categoryCode: 'food',
      expenseType: ExpenseType.oneTime,
    );

void main() {
  test('projects future free cash from historical discretionary spending', () async {
    final incomeRepository = _IncomeRepo(
      IncomeSource(
        userId: 'user-1',
        name: 'Salary',
        sourceType: 'salary',
        amount: 10000,
        currencyCode: 'EGP',
        frequency: 'monthly',
        enabled: true,
      ),
    );
    final expenseRepository = _ExpenseRepo([
      _expense('e-6', 6, 200000),
      _expense('e-7', 7, 300000),
      _expense('e-8', 8, 100000),
    ]);
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(repository: incomeRepository),
      obligationService: ObligationService(repository: _ObligationRepo()),
      expenseService: ExpenseManagementService(
        expenseRepository: expenseRepository,
        recurringRepository: _RecurringRepo(),
      ),
    );

    final forecast = await CashflowForecastService(
      financialEngine: engine,
    ).forecast(
      userId: 'user-1',
      year: 2026,
      month: 9,
      currencyCode: 'EGP',
      historyMonths: 3,
      forecastMonths: 3,
    );

    expect(forecast.currencyCode, 'EGP');
    expect(forecast.historyMonthsUsed, 3);
    expect(forecast.averageDiscretionaryExpenseMinorUnits, 200000);
    expect(forecast.points.map((point) => point.periodLabel), ['10/2026', '11/2026', '12/2026']);
    expect(forecast.points.every((point) => point.incomeMinorUnits == 1000000), isTrue);
    expect(forecast.points.every((point) => point.projectedFreeCashMinorUnits == 800000), isTrue);
    expect(forecast.isPositive, isTrue);
  });

  test('rejects invalid history and forecast ranges', () async {
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(
        repository: _IncomeRepo(
          IncomeSource(
            userId: 'user-1',
            name: 'Salary',
            sourceType: 'salary',
            amount: 10000,
            currencyCode: 'EGP',
            frequency: 'monthly',
            enabled: true,
          ),
        ),
      ),
      obligationService: ObligationService(repository: _ObligationRepo()),
      expenseService: ExpenseManagementService(
        expenseRepository: _ExpenseRepo([]),
        recurringRepository: _RecurringRepo(),
      ),
    );
    final service = CashflowForecastService(financialEngine: engine);

    await expectLater(
      service.forecast(
        userId: 'user-1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 0,
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      service.forecast(
        userId: 'user-1', year: 2026, month: 9, currencyCode: 'EGP', forecastMonths: 13,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
