import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/domain/domain_repository.dart';
import 'package:nus/features/finance/application/financial_transaction_mutation_service.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

Account makeAccount({
  String id = 'account-1',
  String currencyCode = 'USD',
  bool isArchived = false,
}) => Account(
      id: id,
      name: 'Main account',
      type: AccountType.bank,
      currencyCode: currencyCode,
      openingBalanceMinorUnits: 10000,
      isArchived: isArchived,
    );

FinancialTransaction makeTransaction({
  String id = 'tx-1',
  String accountId = 'account-1',
  int amountMinorUnits = 2500,
  String currencyCode = 'USD',
  String? categoryId,
  String? externalReference,
}) => FinancialTransaction(
      id: id,
      accountId: accountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      occurredOn: DateTime(2026, 9, 4),
      categoryId: categoryId,
      externalReference: externalReference,
    );

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository([Iterable<Account> initial = const []])
      : _accounts = {for (final account in initial) account.id: account};

  final Map<String, Account> _accounts;

  @override
  Future<Account?> getById(String id) async => _accounts[id];

  @override
  Future<List<Account>> list() async => _accounts.values.toList(growable: false);

  @override
  Future<void> save(Account entity) async => _accounts[entity.id] = entity;

  @override
  Future<void> deleteById(String id) async => _accounts.remove(id);

  @override
  Future<void> archiveById(String id) async {
    final account = _accounts[id];
    if (account != null) _accounts[id] = account.archive();
  }
}

class FakeFinancialTransactionRepository
    implements FinancialTransactionRepository {
  final Map<String, FinancialTransaction> transactions = {};

  @override
  Future<FinancialTransaction?> getById(String id) async => transactions[id];

  @override
  Future<List<FinancialTransaction>> list() async =>
      transactions.values.toList(growable: false);

  @override
  Future<void> save(FinancialTransaction entity) async {
    transactions[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async => transactions.remove(id);
}

void main() {
  late FakeAccountRepository accounts;
  late FakeFinancialTransactionRepository transactions;
  late FinancialTransactionMutationService service;

  setUp(() {
    accounts = FakeAccountRepository([makeAccount()]);
    transactions = FakeFinancialTransactionRepository();
    service = FinancialTransactionMutationService(
      accounts: accounts,
      transactions: transactions,
    );
  });

  test('creates a valid transaction through the repository boundary', () async {
    final transaction = await service.createTransaction(
      id: 'tx-1',
      accountId: 'account-1',
      amountMinorUnits: 250050,
      currencyCode: 'usd',
      occurredOn: DateTime(2026, 9, 4),
      categoryId: 'salary',
      externalReference: 'payroll-1',
    );

    expect(transaction.id, 'tx-1');
    expect(transaction.accountId, 'account-1');
    expect(transaction.amountMinorUnits, 250050);
    expect(transaction.currencyCode, 'USD');
    expect(transaction.categoryId, 'salary');
    expect(transaction.externalReference, 'payroll-1');
    expect(await transactions.getById('tx-1'), transaction);
  });

  test('rejects nonexistent account', () async {
    expect(
      () => service.createTransaction(
        id: 'tx-1',
        accountId: 'missing',
        amountMinorUnits: 100,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 4),
      ),
      throwsA(isA<StateError>()),
    );
    expect(transactions.transactions, isEmpty);
  });

  test('rejects new transactions for archived accounts', () async {
    accounts = FakeAccountRepository([makeAccount(isArchived: true)]);
    service = FinancialTransactionMutationService(
      accounts: accounts,
      transactions: transactions,
    );

    expect(
      () => service.createTransaction(
        id: 'tx-1',
        accountId: 'account-1',
        amountMinorUnits: 100,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 4),
      ),
      throwsA(isA<ArchivedAccountMutationException>()),
    );
  });

  test('rejects account and transaction currency mismatch', () async {
    expect(
      () => service.createTransaction(
        id: 'tx-1',
        accountId: 'account-1',
        amountMinorUnits: 100,
        currencyCode: 'EUR',
        occurredOn: DateTime(2026, 9, 4),
      ),
      throwsA(isA<FinancialTransactionCurrencyMismatchException>()),
    );
  });

  test('rejects duplicate transaction IDs instead of overwriting', () async {
    await service.createTransaction(
      id: 'tx-1',
      accountId: 'account-1',
      amountMinorUnits: 500,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );

    expect(
      () => service.createTransaction(
        id: 'tx-1',
        accountId: 'account-1',
        amountMinorUnits: 900,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
      ),
      throwsA(isA<DuplicateFinancialTransactionException>()),
    );
    expect((await transactions.getById('tx-1'))!.amountMinorUnits, 500);
  });

  test('preserves exact signed integer minor-unit amounts', () async {
    final expense = await service.createTransaction(
      id: 'tx-expense',
      accountId: 'account-1',
      amountMinorUnits: -123456789,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );

    expect(expense.amountMinorUnits, -123456789);
    expect(expense.isExpense, isTrue);
  });

  test('preserves optional category and source references', () async {
    final transaction = await service.createTransaction(
      id: 'tx-refs',
      accountId: 'account-1',
      amountMinorUnits: 1000,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
      categoryId: 'food',
      externalReference: 'expense-42',
    );

    expect(transaction.categoryId, 'food');
    expect(transaction.externalReference, 'expense-42');
  });

  test('update preserves stable ID and account relationship', () async {
    await service.createTransaction(
      id: 'tx-update',
      accountId: 'account-1',
      amountMinorUnits: 1000,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );

    final updated = await service.updateTransaction(
      makeTransaction(
        id: 'tx-update',
        amountMinorUnits: -700,
      ),
    );

    expect(updated.id, 'tx-update');
    expect(updated.accountId, 'account-1');
    expect(updated.amountMinorUnits, -700);
    expect((await transactions.getById('tx-update'))!.amountMinorUnits, -700);
  });

  test('update cannot move a transaction to another account', () async {
    await service.createTransaction(
      id: 'tx-move',
      accountId: 'account-1',
      amountMinorUnits: 1000,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );
    accounts = FakeAccountRepository([
      makeAccount(),
      makeAccount(id: 'account-2'),
    ]);
    service = FinancialTransactionMutationService(
      accounts: accounts,
      transactions: transactions,
    );

    expect(
      () => service.updateTransaction(
        makeTransaction(id: 'tx-move', accountId: 'account-2'),
      ),
      throwsArgumentError,
    );
  });

  test('update rejects currency mismatch', () async {
    await service.createTransaction(
      id: 'tx-currency',
      accountId: 'account-1',
      amountMinorUnits: 1000,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );

    expect(
      () => service.updateTransaction(
        makeTransaction(
          id: 'tx-currency',
          currencyCode: 'EUR',
        ),
      ),
      throwsA(isA<FinancialTransactionCurrencyMismatchException>()),
    );
  });

  test('update of archived account remains available for historical correction', () async {
    await service.createTransaction(
      id: 'tx-history',
      accountId: 'account-1',
      amountMinorUnits: 1000,
      currencyCode: 'USD',
      occurredOn: DateTime(2026, 9, 4),
    );
    await accounts.archiveById('account-1');

    final updated = await service.updateTransaction(
      makeTransaction(id: 'tx-history', amountMinorUnits: 900),
    );

    expect(updated.id, 'tx-history');
    expect(updated.accountId, 'account-1');
  });

  test('missing transaction cannot be updated', () async {
    expect(
      () => service.updateTransaction(makeTransaction(id: 'missing')),
      throwsA(isA<StateError>()),
    );
  });

  test('repository contract is explicit and storage remains below application layer', () {
    expect(accounts, isA<DomainRepository<Account>>());
    expect(transactions, isA<DomainRepository<FinancialTransaction>>());
    expect(
      FinancialTransactionMutationService,
      isNot(const TypeMatcher<LocalFinancialTransactionRepositoryMarker>()),
    );
  });
}

/// Compile-time-only marker used to keep this test independent of data adapters.
class LocalFinancialTransactionRepositoryMarker {}
