import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/domain/currency_registry.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_category.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/expense_type.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/expenses/application/expense_management_service.dart';

class _ExpenseRepo implements ExpenseRepository {
  final Map<String, Expense> data = {};
  @override Future<Expense?> getById(String id) async => data[id];
  @override Future<List<Expense>> list() async => List<Expense>.of(data.values);
  @override Future<void> save(Expense e) async => data[e.id] = e;
  @override Future<void> deleteById(String id) async => data.remove(id);
}

class _RecurringRepo implements RecurringExpenseRepository {
  final Map<String, RecurringExpenseDefinition> data = {};
  @override Future<RecurringExpenseDefinition?> getById(String id) async => data[id];
  @override Future<List<RecurringExpenseDefinition>> list() async => List<RecurringExpenseDefinition>.of(data.values);
  @override Future<void> save(RecurringExpenseDefinition e) async => data[e.id] = e;
  @override Future<void> deleteById(String id) async => data.remove(id);
  @override Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled) async { final d = data[id]!; final next = d.copyWith(enabled: enabled); data[id] = next; return next; }
}

Expense _expense({String id='e1', int minor=1000, String currency='EGP', String category='food', ExpenseType type=ExpenseType.oneTime, ExpenseDate? date, String userId='u1', String? recurringId}) => Expense(id:id,userId:userId,amount:Money(minorUnits:minor,currencyCode:currency),date:date ?? ExpenseDate(year:2026,month:9,day:7),categoryCode:category,expenseType:type,recurringDefinitionId:recurringId);
RecurringExpenseDefinition _recurring({String id='r1', int minor=50000, String currency='EGP', String frequency='monthly', ExpenseDate? start, ExpenseDate? end, bool enabled=true}) => RecurringExpenseDefinition(id:id,userId:'u1',name:'Internet',amount:Money(minorUnits:minor,currencyCode:currency),categoryCode:'subscriptions',frequency:frequency,enabled:enabled,startDate:start ?? ExpenseDate(year:2026,month:1,day:1),endDate:end);

void main() {
  test('currency registry exposes explicit exponents and rejects unknown currencies', () {
    expect(CurrencyRegistry.get('EGP').exponent, 2);
    expect(CurrencyRegistry.get('JPY').exponent, 0);
    expect(CurrencyRegistry.get('KWD').exponent, 3);
    expect(CurrencyRegistry.majorToMinor(250, 'EGP'), 25000);
    expect(CurrencyRegistry.minorToMajorExact(25000, 'EGP'), 250);
    expect(() => CurrencyRegistry.get('XYZ'), throwsA(isA<ArgumentError>()));
    expect(() => CurrencyRegistry.minorToMajorExact(1, 'EGP'), throwsA(isA<ArgumentError>()));
  });

  test('category and expense type have stable machine identities', () {
    expect(ExpenseCategories.requireCode(' FOOD '), 'food');
    expect(ExpenseType.oneTime.code, 'one_time');
    expect(ExpenseType.variable.code, 'variable');
    expect(ExpenseType.recurring.code, 'recurring');
    expect(() => ExpenseCategories.requireCode('أكل'), throwsA(isA<ArgumentError>()));
  });

  test('authoritative expense requires supported category/currency and recurring link semantics', () {
    expect(() => _expense(category: 'unknown'), throwsA(isA<ArgumentError>()));
    expect(() => _expense(type: ExpenseType.recurring), throwsA(isA<ArgumentError>()));
    expect(() => Expense(id:'e2',userId:'u1',amount:Money(minorUnits:100,currencyCode:'XYZ'),date:ExpenseDate(year:2026,month:1,day:1),categoryCode:'food'), throwsA(isA<ArgumentError>()));
    expect(_expense(type: ExpenseType.recurring, recurringId:'r1').recurringDefinitionId, 'r1');
  });

  test('recurring normalization is deterministic and respects effective dates', () {
    expect(_recurring(minor:50000, frequency:'monthly').normalizedMonthlyAmount, 50000);
    expect(_recurring(minor:100, frequency:'weekly').normalizedMonthlyAmount, 433);
    expect(_recurring(minor:100, frequency:'biweekly').normalizedMonthlyAmount, 217);
    expect(_recurring(minor:100, frequency:'quarterly').normalizedMonthlyAmount, 33);
    expect(_recurring(minor:100, frequency:'yearly').normalizedMonthlyAmount, 8);
    final definition = _recurring(start:ExpenseDate(year:2026,month:9,day:15), end:ExpenseDate(year:2026,month:10,day:10));
    expect(definition.appliesToMonth(2026, 8), isFalse);
    expect(definition.appliesToMonth(2026, 9), isTrue);
    expect(definition.appliesToMonth(2026, 10), isTrue);
    expect(definition.appliesToMonth(2026, 11), isFalse);
    expect(_recurring(enabled:false).appliesToMonth(2026,9), isFalse);
  });

  test('service aggregates actuals and expected recurring only within the requested currency', () async {
    final expenses = _ExpenseRepo()
      ..data['a'] = _expense(id:'a',minor:10000,category:'food')
      ..data['b'] = _expense(id:'b',minor:2500,category:'food',date:ExpenseDate(year:2026,month:8,day:1))
      ..data['c'] = _expense(id:'c',minor:5000,currency:'USD',category:'shopping');
    final recurring = _RecurringRepo()
      ..data['r1'] = _recurring(id:'r1',minor:50000)
      ..data['r2'] = _recurring(id:'r2',minor:1000,currency:'USD');
    final service = ExpenseManagementService(expenseRepository: expenses, recurringRepository: recurring);
    expect(await service.monthlyActualTotal(year:2026,month:9,currencyCode:'EGP'), 10000);
    expect(await service.monthlyActualTotal(year:2026,month:9,currencyCode:'USD'), 5000);
    expect(await service.monthlyExpectedRecurringTotal(year:2026,month:9,currencyCode:'EGP'), 50000);
    expect(await service.monthlyExpectedRecurringTotal(year:2026,month:9,currencyCode:'USD'), (1000*12+6)~/12);
    expect(await service.monthlyActualByCategory(year:2026,month:9,currencyCode:'EGP'), {'food':10000});
  });

  test('definition changes do not rewrite historical occurrence data', () async {
    final expenses = _ExpenseRepo()..data['actual'] = _expense(id:'actual',minor:50000,recurringId:'r1',type:ExpenseType.recurring);
    final recurring = _RecurringRepo()..data['r1'] = _recurring(minor:50000);
    final service = ExpenseManagementService(expenseRepository: expenses, recurringRepository: recurring);
    final before = expenses.data['actual']!.toJson();
    await service.updateRecurring(_recurring(id:'r1',minor:80000));
    expect(expenses.data['actual']!.toJson(), before);
    expect(recurring.data['r1']!.amount.minorUnits, 80000);
  });
}
