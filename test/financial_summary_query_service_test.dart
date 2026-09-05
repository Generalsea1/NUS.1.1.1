import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/finance/application/financial_summary_query_service.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

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
  late Accounts accounts; late Transactions transactions; late FinancialSummaryQueryService query;
  setUp(() {
    accounts = Accounts(); transactions = Transactions();
    accounts.data['a1'] = Account(id: 'a1', name: 'Main', type: AccountType.bank, currencyCode: 'EGP', openingBalanceMinorUnits: 10000);
    transactions.data['income'] = FinancialTransaction(id: 'income', accountId: 'a1', amountMinorUnits: 5000, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 9, 2), categoryId: 'salary');
    transactions.data['food'] = FinancialTransaction(id: 'food', accountId: 'a1', amountMinorUnits: -1200, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 9, 3), categoryId: 'food');
    transactions.data['other'] = FinancialTransaction(id: 'other', accountId: 'a1', amountMinorUnits: -300, currencyCode: 'EGP', occurredOn: DateTime.utc(2026, 8, 31), categoryId: 'food');
    transactions.data['usd'] = FinancialTransaction(id: 'usd', accountId: 'a1', amountMinorUnits: 9000, currencyCode: 'USD', occurredOn: DateTime.utc(2026, 9, 4));
    query = FinancialSummaryQueryService(transactionRepository: transactions, accountRepository: accounts);
  });

  test('period summary uses exact signed money and currency isolation', () async {
    final summary = await query.periodSummary(currencyCode: 'egp', start: DateTime.utc(2026, 9, 1), end: DateTime.utc(2026, 10, 1));
    expect(summary.incomeMinorUnits, 5000);
    expect(summary.expenseMinorUnits, 1200);
    expect(summary.netCashFlowMinorUnits, 3800);
  });

  test('category spending only includes negative categorized transactions', () async {
    final result = await query.categorySpending(currencyCode: 'EGP', start: DateTime.utc(2026, 9, 1), end: DateTime.utc(2026, 10, 1));
    expect(result.single.categoryId, 'food');
    expect(result.single.amountMinorUnits, 1200);
  });

  test('account balance is opening balance plus signed compatible ledger', () async {
    expect(await query.accountBalance('a1'), 13500);
  });

  test('monthly trend preserves month boundaries', () async {
    final trend = await query.monthlyTrend(currencyCode: 'EGP', firstMonth: DateTime.utc(2026, 8, 1), monthCount: 2);
    expect(trend, hasLength(2));
    expect(trend[0].expenseMinorUnits, 300);
    expect(trend[1].netCashFlowMinorUnits, 3800);
  });

  test('invalid month count and currency are rejected', () async {
    expect(() => query.monthlyTrend(currencyCode: 'EGP', firstMonth: DateTime.utc(2026, 9), monthCount: 0), throwsA(isA<ArgumentError>()));
    expect(() => query.periodSummary(currencyCode: 'EGP1', start: DateTime.utc(2026, 9), end: DateTime.utc(2026, 10)), throwsA(isA<ArgumentError>()));
  });

  test('transaction currency corruption fails closed for account balance', () async {
    expect(() => query.accountBalance('a1'), returnsNormally);
    // The USD transaction is deliberately attached to the EGP account and must fail.
    await expectLater(query.accountBalance('a1'), throwsA(isA<FinancialSummaryCurrencyMismatchException>()));
  });
}
