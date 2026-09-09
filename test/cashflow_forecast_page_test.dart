import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/expense_type.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/finance/application/cashflow_forecast_service.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/finance/presentation/cashflow_forecast_page.dart';
import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/domain/income_source.dart';
import 'package:nus/features/obligations/application/obligation_repository.dart';
import 'package:nus/features/obligations/application/obligation_service.dart';
import 'package:nus/features/obligations/domain/obligation.dart';

class _IncomeRepo implements IncomeSourceRepository {
  @override
  Future<List<IncomeSource>> list(String userId) async => [
        IncomeSource(
          userId: userId,
          name: 'Salary',
          sourceType: 'salary',
          amount: 10000,
          currencyCode: 'EGP',
          frequency: 'monthly',
          enabled: true,
        ),
      ];

  @override
  Future<IncomeSource> create(IncomeSource source) async => source;
  @override
  Future<IncomeSource> update(IncomeSource source) async => source;
  @override
  Future<void> delete(String userId, String sourceId) async {}
  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async =>
      (await list(userId)).single.copyWith(enabled: enabled);
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
  @override
  Future<Expense?> getById(String id) async => null;
  @override
  Future<List<Expense>> list() async => [
        Expense(
          id: 'e1',
          userId: 'user-1',
          amount: Money(minorUnits: 200000, currencyCode: 'EGP'),
          date: ExpenseDate(year: 2026, month: 8, day: 10),
          categoryCode: 'food',
          expenseType: ExpenseType.oneTime,
        ),
      ];
  @override
  Future<void> save(Expense expense) async {}
  @override
  Future<void> deleteById(String id) async {}
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
  Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) async =>
      throw UnimplementedError();
}

CashflowForecastService _service() {
  final expenseService = ExpenseManagementService(
    expenseRepository: _ExpenseRepo(),
    recurringRepository: _RecurringRepo(),
  );
  return CashflowForecastService(
    financialEngine: FinancialEngine(
      incomeService: IncomeSourceService(repository: _IncomeRepo()),
      obligationService: ObligationService(repository: _ObligationRepo()),
      expenseService: expenseService,
    ),
  );
}

void main() {
  testWidgets('renders forecast summary and future months', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashflowForecastPage(
          userId: 'user-1',
          year: 2026,
          month: 9,
          currencyCode: 'EGP',
          service: _service(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('cashflow-forecast-status')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashflow-forecast-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashflow-point-10/2026')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cashflow-forecast-status-positive')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('cashflow-point-11/2026')),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const ValueKey<String>('cashflow-point-11/2026')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey<String>('cashflow-point-12/2026')),
      400,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const ValueKey<String>('cashflow-point-12/2026')), findsOneWidget);
  });
}
