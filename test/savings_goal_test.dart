import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/finance/application/savings_goal_service.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';
import 'package:nus/features/finance/domain/savings_goal.dart';

class Goals implements SavingsGoalRepository {
  final Map<String, SavingsGoal> data = {};
  Future<SavingsGoal?> getById(String id) async => data[id.trim()];
  Future<List<SavingsGoal>> list() async => data.values.toList(growable: false);
  Future<void> save(SavingsGoal goal) async => data[goal.id] = goal;
  Future<void> archiveById(String id) async { final g = data[id.trim()]; if (g != null) data[id.trim()] = g.archive(); }
}
class Accounts implements AccountRepository {
  final Map<String, Account> data = {};
  Future<Account?> getById(String id) async => data[id.trim()];
  Future<List<Account>> list() async => data.values.toList(growable: false);
  Future<void> save(Account a) async => data[a.id] = a;
  Future<void> deleteById(String id) async => data.remove(id.trim());
  Future<void> archiveById(String id) async { final a = data[id.trim()]; if (a != null) data[id.trim()] = a.archive(); }
}
class Transactions implements FinancialTransactionRepository {
  final Map<String, FinancialTransaction> data = {};
  Future<FinancialTransaction?> getById(String id) async => data[id.trim()];
  Future<List<FinancialTransaction>> list() async => data.values.toList(growable: false);
  Future<void> save(FinancialTransaction t) async => data[t.id] = t;
  Future<void> deleteById(String id) async => data.remove(id.trim());
}

void main() {
  late Goals goals; late Accounts accounts; late Transactions transactions;
  late SavingsGoalMutationService mutation; late SavingsGoalQueryService query;
  setUp(() {
    goals = Goals(); accounts = Accounts(); transactions = Transactions();
    accounts.data['a1'] = Account(id: 'a1', name: 'Savings', type: AccountType.bank, currencyCode: 'EGP', openingBalanceMinorUnits: 0);
    mutation = SavingsGoalMutationService(goalRepository: goals, accountRepository: accounts);
    query = SavingsGoalQueryService(goalRepository: goals, accountRepository: accounts, transactionRepository: transactions);
  });
  SavingsGoal goal({int target = 20000, String currency = 'EGP'}) => SavingsGoal(id: 'g1', name: 'Emergency fund', targetMinorUnits: target, currencyCode: currency, targetDate: DateTime.utc(2027, 1, 1), progressAccountId: 'a1');

  test('exact target and canonical currency round trip', () {
    final g = goal(currency: 'egp');
    expect(g.currencyCode, 'EGP');
    expect(SavingsGoal.fromJson(g.toJson()), g);
  });
  test('invalid target/currency rejected', () {
    expect(() => goal(target: 0), throwsA(isA<FormatException>()));
    expect(() => goal(currency: 'USDT'), throwsA(isA<FormatException>()));
  });
  test('create rejects duplicate, missing and archived accounts', () async {
    await mutation.create(goal());
    expect(() => mutation.create(goal()), throwsA(isA<SavingsGoalDuplicateIdException>()));
    expect(() => mutation.create(goal().copyWith(id: 'g2', progressAccountId: 'missing')), throwsA(isA<SavingsGoalAccountNotFoundException>()));
    accounts.data['a2'] = accounts.data['a1']!.archive();
    expect(() => mutation.create(goal().copyWith(id: 'g3', progressAccountId: 'a2')), throwsA(isA<SavingsGoalArchivedAccountException>()));
  });
  test('account currency must match goal', () async {
    expect(() => mutation.create(goal(currency: 'USD')), throwsA(isA<SavingsGoalCurrencyMismatchException>()));
  });
  test('progress derives from signed transactions and never persists a counter', () async {
    await mutation.create(goal());
    transactions.data['t1'] = FinancialTransaction(id: 't1', accountId: 'a1', amountMinorUnits: 7000, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 9, 1));
    transactions.data['t2'] = FinancialTransaction(id: 't2', accountId: 'a1', amountMinorUnits: -2000, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 9, 2));
    final p = await query.progressFor('g1');
    expect(p.progressMinorUnits, 5000); expect(p.remainingMinorUnits, 15000); expect(p.isReached, isFalse);
  });
  test('reached goal clamps remaining to zero', () async {
    await mutation.create(goal(target: 5000));
    transactions.data['t1'] = FinancialTransaction(id: 't1', accountId: 'a1', amountMinorUnits: 6000, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 9, 1));
    final p = await query.progressFor('g1');
    expect(p.progressMinorUnits, 6000); expect(p.remainingMinorUnits, 0); expect(p.isReached, isTrue);
  });
  test('currency corruption in ledger fails closed', () async {
    await mutation.create(goal());
    transactions.data['bad'] = FinancialTransaction(id: 'bad', accountId: 'a1', amountMinorUnits: 100, currencyCode: 'USD', occurredOn: DateTime.utc(2026, 9, 1));
    expect(() => query.progressFor('g1'), throwsA(isA<SavingsGoalTransactionCurrencyMismatchException>()));
  });
  test('archive preserves stable identity', () async {
    await mutation.create(goal()); await mutation.archive('g1');
    expect(goals.data['g1']!.isArchived, isTrue);
  });
}
