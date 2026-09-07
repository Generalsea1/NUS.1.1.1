import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/currency_registry.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_category.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/expense_type.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';

class _ExpenseRepo implements ExpenseRepository {
  _ExpenseRepo([List<Expense>? initial])
      : items = List<Expense>.of(initial ?? const []);
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
  final Map<String, RecurringExpenseDefinition> data = {};

  @override
  Future<RecurringExpenseDefinition?> getById(String id) async => data[id];

  @override
  Future<List<RecurringExpenseDefinition>> list() async =>
      List<RecurringExpenseDefinition>.of(data.values);

  @override
  Future<void> save(RecurringExpenseDefinition expense) async =>
      data[expense.id] = expense;

  @override
  Future<void> deleteById(String id) async => data.remove(id);

  @override
  Future<RecurringExpenseDefinition> setEnabled(
    String userId,
    String id,
    bool enabled,
  ) async {
    final definition = data[id]!;
    final updated = definition.copyWith(enabled: enabled);
    data[id] = updated;
    return updated;
  }
}

Expense _expense({
  String id = 'e1',
  int minor = 1000,
  String currency = 'EGP',
  String category = 'food',
  ExpenseType type = ExpenseType.oneTime,
  ExpenseDate? date,
  String userId = 'u1',
  String? recurringId,
}) => Expense(
      id: id,
      userId: userId,
      amount: Money(minorUnits: minor, currencyCode: currency),
      date: date ?? ExpenseDate(year: 2026, month: 9, day: 7),
      categoryCode: category,
      expenseType: type,
      recurringDefinitionId: recurringId,
    );

RecurringExpenseDefinition _recurring({
  String id = 'r1',
  int minor = 50000,
  String currency = 'EGP',
  String frequency = 'monthly',
  ExpenseDate? start,
  ExpenseDate? end,
  bool enabled = true,
}) => RecurringExpenseDefinition(
      id: id,
      userId: 'u1',
      name: 'Internet',
      amount: Money(minorUnits: minor, currencyCode: currency),
      categoryCode: 'subscriptions',
      frequency: frequency,
      enabled: enabled,
      startDate: start ?? ExpenseDate(year: 2026, month: 1, day: 1),
      endDate: end,
    );

void main() {
  test('currency registry uses explicit exponents and rejects unknown currencies', () {
    expect(CurrencyRegistry.get('EGP').exponent, 2);
    expect(CurrencyRegistry.get('JPY').exponent, 0);
    expect(CurrencyRegistry.get('KWD').exponent, 3);
    expect(CurrencyRegistry.majorToMinor(250, 'EGP'), 25000);
    expect(CurrencyRegistry.minorToMajorExact(25000, 'EGP'), 250);
    expect(() => CurrencyRegistry.get('XYZ'), throwsA(isA<ArgumentError>()));
    expect(() => CurrencyRegistry.minorToMajorExact(1, 'EGP'),
        throwsA(isA<ArgumentError>()));
  });

  test('category and expense type have stable machine identities', () {
    expect(ExpenseCategories.requireCode(' FOOD '), 'food');
    expect(ExpenseType.oneTime.code, 'one_time');
    expect(ExpenseType.variable.code, 'variable');
    expect(ExpenseType.recurring.code, 'recurring');
    expect(() => ExpenseCategories.requireCode('أكل'),
        throwsA(isA<ArgumentError>()));
  });

  test('authoritative expense validates category/currency', () {
    expect(() => _expense(category: 'unknown'), throwsA(isA<ArgumentError>()));
    expect(
      () => Expense(
        id: 'e2',
        userId: 'u1',
        amount: Money(minorUnits: 100, currencyCode: 'XYZ'),
        date: ExpenseDate(year: 2026, month: 1, day: 1),
        categoryCode: 'food',
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(_expense(type: ExpenseType.recurring, recurringId: 'r1')
        .recurringDefinitionId, 'r1');
  });

  test('service rejects recurring actuals without a definition', () async {
    final service = ExpenseManagementService(
      expenseRepository: _ExpenseRepo(),
      recurringRepository: _RecurringRepo(),
    );
    await expectLater(
      service.createExpense(_expense(type: ExpenseType.recurring)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('recurring normalization is deterministic and respects effective dates', () {
    expect(_recurring(minor: 50000, frequency: 'monthly').normalizedMonthlyAmount,
        50000);
    expect(_recurring(minor: 100, frequency: 'weekly').normalizedMonthlyAmount, 433);
    expect(_recurring(minor: 100, frequency: 'biweekly').normalizedMonthlyAmount, 217);
    expect(_recurring(minor: 100, frequency: 'quarterly').normalizedMonthlyAmount, 33);
    expect(_recurring(minor: 100, frequency: 'yearly').normalizedMonthlyAmount, 8);
    final definition = _recurring(
      start: ExpenseDate(year: 2026, month: 9, day: 15),
      end: ExpenseDate(year: 2026, month: 10, day: 10),
    );
    expect(definition.appliesToMonth(2026, 8), isFalse);
    expect(definition.appliesToMonth(2026, 9), isTrue);
    expect(definition.appliesToMonth(2026, 10), isTrue);
    expect(definition.appliesToMonth(2026, 11), isFalse);
    expect(_recurring(enabled: false).appliesToMonth(2026, 9), isFalse);
  });

  test('service aggregates actuals and expected recurring by currency', () async {
    final expenses = _ExpenseRepo([
      _expense(id: 'a', minor: 10000, category: 'food'),
      _expense(
        id: 'b',
        minor: 2500,
        category: 'food',
        date: ExpenseDate(year: 2026, month: 8, day: 1),
      ),
      _expense(id: 'c', minor: 5000, currency: 'USD', category: 'shopping'),
    ]);
    final recurring = _RecurringRepo()
      ..data['r1'] = _recurring(id: 'r1', minor: 50000)
      ..data['r2'] = _recurring(id: 'r2', minor: 1000, currency: 'USD');
    final service = ExpenseManagementService(
      expenseRepository: expenses,
      recurringRepository: recurring,
    );
    expect(await service.monthlyActualTotal(
        year: 2026, month: 9, currencyCode: 'EGP'), 10000);
    expect(await service.monthlyActualTotal(
        year: 2026, month: 9, currencyCode: 'USD'), 5000);
    expect(await service.monthlyExpectedRecurringTotal(
        year: 2026, month: 9, currencyCode: 'EGP'), 50000);
    expect(await service.monthlyExpectedRecurringTotal(
        year: 2026, month: 9, currencyCode: 'USD'), 1000);
    expect(await service.monthlyActualByCategory(
        year: 2026, month: 9, currencyCode: 'EGP'), {'food': 10000});
  });

  test('recurring definition changes do not rewrite historical occurrences', () async {
    final expenses = _ExpenseRepo([
      _expense(
        id: 'actual',
        minor: 50000,
        recurringId: 'r1',
        type: ExpenseType.recurring,
      ),
    ]);
    final recurring = _RecurringRepo()
      ..data['r1'] = _recurring(minor: 50000);
    final service = ExpenseManagementService(
      expenseRepository: expenses,
      recurringRepository: recurring,
    );
    final before = expenses.items.single.toJson();
    await service.updateRecurring(_recurring(id: 'r1', minor: 80000));
    expect(expenses.items.single.toJson(), before);
    expect(recurring.data['r1']!.amount.minorUnits, 80000);
  });
}
