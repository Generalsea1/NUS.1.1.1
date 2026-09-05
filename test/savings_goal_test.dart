import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/savings_goal_service.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';
import 'package:nus/features/finance/domain/savings_goal.dart';

class FakeGoalRepository implements SavingsGoalRepository {
  final Map<String, SavingsGoal> items = {};
  @override Future<SavingsGoal?> getById(String id) async => items[id.trim()];
  @override Future<List<SavingsGoal>> list() async => items.values.toList(growable: false);
  @override Future<void> save(SavingsGoal goal) async => items[goal.id] = goal;
  @override Future<void> archiveById(String id) async {
    final goal = items[id.trim()];
    if (goal != null) items[id.trim()] = goal.archive();
  }
}

class FakeAccountRepository implements AccountRepository {
  final Map<String, Account> items = {};
  @override Future<Account?> getById(String id) async => items[id.trim()];
  @override Future<List<Account>> list() async => items.values.toList(growable: false);
  @override Future<void> save(Account entity) async => items[entity.id] = entity;
  @override Future<void> deleteById(String id) async => items.remove(id.trim());
  @override Future<void> archiveById(String id) async {
    final account = items[id.trim()];
    if (account != null) items[id.trim()] = account.archive();
  }
}

class FakeTransactionRepository implements FinancialTransactionRepository {
  final Map<String, FinancialTransaction> items = {};
  @override Future<FinancialTransaction?> getById(String id) async => items[id.trim()];
  @override Future<List<FinancialTransaction>> list() async => items.values.toList(growable: false);
  @override Future<void> save(FinancialTransaction entity) async => items[entity.id] = entity;
  @override Future<void> deleteById(String id) async => items.remove(id.trim());
}

void main() {
  late FakeGoalRepository goals;
  late FakeAccountRepository accounts;
  late FakeTransactionRepository transactions;
  late SavingsGoalMutationService mutation;
  late SavingsGoalQueryService query;

  setUp(() {
    goals = FakeGoalRepository();
    accounts = FakeAccountRepository();
    transactions = FakeTransactionRepository();
    mutation = SavingsGoalMutationService(
      goalRepository: goals,
      accountRepository: accounts,
    );
    query = SavingsGoalQueryService(
      goalRepository: goals,
      accountRepository: accounts,
      transactionRepository: transactions,
    );
    accounts.items['a1'] = Account(
      id: 'a1',
      name: 'Savings',
      type: AccountType.bank,
      currencyCode: 'EGP',
      openingBalanceMinorUnits: 10000,
    );
  });

  SavingsGoal goal({int target = 20000, String currency = 'EGP'}) => SavingsGoal(
        id: 'g1',
        name: 'Emergency fund',
        targetMinorUnits: target,
        currencyCode: currency,
        targetDate: DateTime.utc(2027, 1, 1),
        progressAccountId: 'a1',
      );

  test('domain normalizes currency and serializes exact target', () {
    final value = goal(currency: 'egp');
    expect(value.currencyCode, 'EGP');
    expect(value.toJson()['targetMinorUnits'], 20000);
    expect(SavingsGoal.fromJson(value.toJson()), value);
  });

  test('domain rejects invalid money and currency', () {
    expect(() => goal(target: 0), throwsA(isA<FormatException>()));
    expect(() => goal(currency: 'USDT'), throwsA(isA<FormatException>()));
  });

  test('create validates account and duplicate identity', () async {
    await mutation.create(goal());
    expect(
      () => mutation.create(goal()),
      throwsA(isA<SavingsGoalDuplicateIdException>()),
    );
    expect(
      () => mutation.create(goal().copyWith(progressAccountId: 'missing', id: 'g2')),
      throwsA(isA<SavingsGoalAccountNotFoundException>()),
    );
  });

  test('create rejects account currency mismatch', () async {
    expect(
      () => mutation.create(goal(currency: 'USD')),
      throwsA(isA<SavingsGoalCurrencyMismatchException>()),
    );
  });

  test('progress is derived from signed ledger movement', () async {
    await mutation.create(goal());
    transactions.items['t1'] = FinancialTransaction(
      id: 't1', accountId: 'a1', amountMinorUnits: 7000, currencyCode: 'EGP',
      occurredOn: DateTime.utc(2026, 9, 1),
    );
    transactions.items['t2'] = FinancialTransaction(
      id: 't2', accountId: 'a1', amountMinorUnits: -2000, currencyCode: 'EGP',
      occurredOn: DateTime.utc(2026, 9, 2),
    );

    final progress = await query.progressFor('g1');
    expect(progress.progressMinorUnits, 5000);
    expect(progress.remainingMinorUnits, 15000);
    expect(progress.isReached, isFalse);
  });

  test('reached goal never reports negative remaining', () async {
    await mutation.create(goal(target: 5000));
    transactions.items['t1'] = FinancialTransaction(
      id: 't1', accountId: 'a1', amountMinorUnits: 6000, currencyCode: 'EGP',
      occurredOn: DateTime.utc(2026, 9, 1),
    );

    final progress = await query.progressFor('g1');
    expect(progress.progressMinorUnits, 6000);
    expect(progress.remainingMinorUnits, 0);
    expect(progress.isReached, isTrue);
  });

  test('transaction currency mismatch fails closed', () async {
    await mutation.create(goal());
    transactions.items['bad'] = FinancialTransaction(
      id: 'bad', accountId: 'a1', amountMinorUnits: 100, currencyCode: 'USD',
      occurredOn: DateTime.utc(2026, 9, 1),
    );
    expect(
      () => query.progressFor('g1'),
      throwsA(isA<SavingsGoalTransactionCurrencyMismatchException>()),
    );
  });

  test('archive preserves stable goal identity', () async {
    await mutation.create(goal());
    await mutation.archive('g1');
    expect(goals.items['g1']!.isArchived, isTrue);
  });
}
