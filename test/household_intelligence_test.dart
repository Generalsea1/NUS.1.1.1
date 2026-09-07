import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/expense_type.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/finance/application/household_intelligence_service.dart';
import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/domain/income_source.dart';
import 'package:nus/features/obligations/application/obligation_repository.dart';
import 'package:nus/features/obligations/application/obligation_service.dart';
import 'package:nus/features/obligations/domain/obligation.dart';

class _ExpenseRepo implements ExpenseRepository {
  _ExpenseRepo(this.items);
  final List<Expense> items;
  @override
  Future<Expense?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
  @override
  Future<List<Expense>> list() async => List<Expense>.from(items);
  @override
  Future<void> save(Expense entity) async => items.add(entity);
  @override
  Future<void> deleteById(String id) async => items.removeWhere((e) => e.id == id);
}

class _RecurringRepo implements RecurringExpenseRepository {
  _RecurringRepo(this.items);
  final List<RecurringExpenseDefinition> items;
  @override
  Future<RecurringExpenseDefinition?> getById(String id) async {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
  @override
  Future<List<RecurringExpenseDefinition>> list() async => List<RecurringExpenseDefinition>.from(items);
  @override
  Future<void> save(RecurringExpenseDefinition entity) async => items.add(entity);
  @override
  Future<void> deleteById(String id) async => items.removeWhere((e) => e.id == id);
  @override
  Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) async {
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) throw StateError('missing recurring definition');
    final value = items[index].copyWith(enabled: enabled);
    items[index] = value;
    return value;
  }
}

class _IncomeRepo implements IncomeSourceRepository {
  _IncomeRepo(this.items);
  final List<IncomeSource> items;
  @override
  Future<List<IncomeSource>> list(String userId) async => items.where((e) => e.userId == userId).toList();
  @override
  Future<IncomeSource> create(IncomeSource source) async { items.add(source); return source; }
  @override
  Future<IncomeSource> update(IncomeSource source) async => source;
  @override
  Future<void> delete(String userId, String sourceId) async {}
  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async =>
      items.firstWhere((e) => e.id == sourceId).copyWith(enabled: enabled);
}

class _ObligationRepo implements ObligationRepository {
  _ObligationRepo(this.items);
  final List<Obligation> items;
  @override
  Future<List<Obligation>> list(String userId) async => items.where((e) => e.userId == userId).toList();
  @override
  Future<Obligation> create(Obligation obligation) async { items.add(obligation); return obligation; }
  @override
  Future<Obligation> update(Obligation obligation) async => obligation;
  @override
  Future<void> delete(String userId, String obligationId) async {}
  @override
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) async =>
      items.firstWhere((e) => e.id == obligationId).copyWith(enabled: enabled);
}

class _Fixture {
  _Fixture({required List<Expense> expenses, List<RecurringExpenseDefinition> recurring = const []})
      : expenseRepository = _ExpenseRepo(expenses),
        recurringRepository = _RecurringRepo(List<RecurringExpenseDefinition>.from(recurring)),
        incomeRepository = _IncomeRepo([
          IncomeSource(
            id: 'income-1',
            userId: 'u1',
            name: 'Salary',
            sourceType: 'salary',
            amount: 10000,
            currencyCode: 'EGP',
            frequency: 'monthly',
            enabled: true,
          ),
        ]),
        obligationRepository = _ObligationRepo([
          Obligation(
            id: 'ob-1',
            userId: 'u1',
            name: 'Rent',
            type: 'rent',
            amount: 2000,
            currencyCode: 'EGP',
            frequency: 'monthly',
            enabled: true,
          ),
        ]) {
    expenseService = ExpenseManagementService(
      expenseRepository: expenseRepository,
      recurringRepository: recurringRepository,
    );
    incomeService = IncomeSourceService(repository: incomeRepository);
    obligationService = ObligationService(repository: obligationRepository);
    financialEngine = FinancialEngine(
      incomeService: incomeService,
      obligationService: obligationService,
      expenseService: expenseService,
    );
    intelligence = HouseholdIntelligenceService(
      financialEngine: financialEngine,
      expenseService: expenseService,
      incomeService: incomeService,
    );
  }

  final _ExpenseRepo expenseRepository;
  final _RecurringRepo recurringRepository;
  final _IncomeRepo incomeRepository;
  final _ObligationRepo obligationRepository;
  late final ExpenseManagementService expenseService;
  late final IncomeSourceService incomeService;
  late final ObligationService obligationService;
  late final FinancialEngine financialEngine;
  late final HouseholdIntelligenceService intelligence;
}

Expense _expense(String id, int year, int month, int minorUnits, String category, {String currency = 'EGP'}) =>
    Expense(
      id: id,
      userId: 'u1',
      amount: Money(minorUnits: minorUnits, currencyCode: currency),
      date: ExpenseDate(year: year, month: month, day: 10),
      categoryCode: category,
      expenseType: ExpenseType.oneTime,
    );

RecurringExpenseDefinition _recurring(String id, int minorUnits) => RecurringExpenseDefinition(
      id: id,
      userId: 'u1',
      name: 'Rent',
      amount: Money(minorUnits: minorUnits, currencyCode: 'EGP'),
      categoryCode: 'housing',
      frequency: 'monthly',
      enabled: true,
      startDate: ExpenseDate(year: 2026, month: 1, day: 1),
    );

void main() {
  test('highest category is deterministic and uses actual expense data', () async {
    final fixture = _Fixture(
      expenses: [
        _expense('a', 2026, 9, 50000, 'food'),
        _expense('b', 2026, 9, 80000, 'transportation'),
        _expense('c', 2026, 9, 20000, 'food'),
      ],
    );
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    final highest = result.insights.firstWhere((i) => i.type == 'highest_category');
    expect(highest.categoryCode, 'transportation');
    expect(highest.valueMinorUnits, 80000);
  });

  test('monthly totals come from Financial Engine and preserve integer arithmetic', () async {
    final fixture = _Fixture(expenses: [
      _expense('a', 2026, 7, 10000, 'food'),
      _expense('b', 2026, 8, 15000, 'food'),
      _expense('c', 2026, 9, 25000, 'food'),
    ]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 3);
    final trend = result.insights.firstWhere((i) => i.type == 'monthly_trend');
    expect(trend.periodValues.map((e) => e.valueMinorUnits), [10000, 15000, 25000]);
  });

  test('monthly trend is available with sufficient history', () async {
    final fixture = _Fixture(expenses: [
      _expense('a', 2026, 7, 10000, 'food'),
      _expense('b', 2026, 8, 15000, 'food'),
      _expense('c', 2026, 9, 25000, 'food'),
    ]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 3);
    expect(result.insights.firstWhere((i) => i.type == 'monthly_trend').dataState, HouseholdDataState.sufficient);
  });

  test('one month of expenses is explicitly insufficient for trend', () async {
    final fixture = _Fixture(expenses: [_expense('a', 2026, 9, 10000, 'food')]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    expect(result.insights.firstWhere((i) => i.type == 'monthly_trend').dataState, HouseholdDataState.insufficient);
  });

  test('increasing and decreasing categories are detected separately', () async {
    final fixture = _Fixture(expenses: [
      _expense('a1', 2026, 7, 10000, 'food'),
      _expense('a2', 2026, 8, 20000, 'food'),
      _expense('a3', 2026, 9, 30000, 'food'),
      _expense('b1', 2026, 7, 30000, 'transportation'),
      _expense('b2', 2026, 8, 20000, 'transportation'),
      _expense('b3', 2026, 9, 10000, 'transportation'),
    ]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 3);
    expect(result.insights.any((i) => i.type == 'category_increasing' && i.categoryCode == 'food'), isTrue);
    expect(result.insights.any((i) => i.type == 'category_decreasing' && i.categoryCode == 'transportation'), isTrue);
  });

  test('recurring expected spending remains separate from actual spending', () async {
    final fixture = _Fixture(
      expenses: [_expense('a', 2026, 9, 15000, 'food')],
      recurring: [_recurring('r1', 70000)],
    );
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    final insight = result.insights.firstWhere((i) => i.type == 'recurring_vs_actual');
    expect(insight.valueMinorUnits, 15000);
    expect(insight.comparisonValueMinorUnits, 70000);
    expect(insight.valueMinorUnits, isNot(insight.comparisonValueMinorUnits));
  });

  test('obligation burden is separated from actual spending without double counting', () async {
    final fixture = _Fixture(expenses: [_expense('a', 2026, 9, 50000, 'debt')]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    final current = result.insights.firstWhere((i) => i.type == 'obligation_burden');
    expect(current.valueMinorUnits, 200000);
    expect(current.comparisonValueMinorUnits, 1000000);
    expect(result.insights.firstWhere((i) => i.type == 'recurring_vs_actual').valueMinorUnits, 50000);
  });

  test('different currencies remain isolated', () async {
    final fixture = _Fixture(expenses: [
      _expense('egp', 2026, 9, 50000, 'food'),
      _expense('usd', 2026, 9, 900000, 'transportation', currency: 'USD'),
    ]);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    expect(result.insights.firstWhere((i) => i.type == 'highest_category').categoryCode, 'food');
    expect(result.insights.firstWhere((i) => i.type == 'recurring_vs_actual').valueMinorUnits, 50000);
  });

  test('empty household reports insufficient data instead of inventing conclusions', () async {
    final fixture = _Fixture(expenses: []);
    final result = await fixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP');
    expect(result.insights.firstWhere((i) => i.type == 'highest_category').dataState, HouseholdDataState.insufficient);
    expect(result.insights.firstWhere((i) => i.type == 'monthly_trend').dataState, HouseholdDataState.insufficient);
    expect(result.insights.firstWhere((i) => i.type == 'income_stability').dataState, HouseholdDataState.insufficient);
    expect(result.insights.firstWhere((i) => i.type == 'recurring_vs_actual').dataState, HouseholdDataState.insufficient);
  });

  test('results are deterministic for identical input', () async {
    final expenses = [
      _expense('a', 2026, 7, 10000, 'food'),
      _expense('b', 2026, 8, 20000, 'food'),
      _expense('c', 2026, 9, 30000, 'food'),
    ];
    final firstFixture = _Fixture(expenses: expenses);
    final secondFixture = _Fixture(expenses: expenses);
    final first = await firstFixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 3);
    final second = await secondFixture.intelligence.analyze(userId: 'u1', year: 2026, month: 9, currencyCode: 'EGP', historyMonths: 3);
    expect(
      first.insights.map((i) => '${i.type}|${i.categoryCode}|${i.valueMinorUnits}|${i.comparisonValueMinorUnits}|${i.dataState}').toList(),
      second.insights.map((i) => '${i.type}|${i.categoryCode}|${i.valueMinorUnits}|${i.comparisonValueMinorUnits}|${i.dataState}').toList(),
    );
  });
}
