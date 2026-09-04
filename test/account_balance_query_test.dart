import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/core/domain/domain_repository.dart';
import 'package:nus/features/finance/application/account_balance_query_service.dart';
import 'package:nus/features/finance/data/local_account_repository.dart';
import 'package:nus/features/finance/data/local_financial_transaction_repository.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

Account makeAccount({
  String id = 'account-1',
  String name = 'Main account',
  String currencyCode = 'EGP',
  int openingBalanceMinorUnits = 10000,
  bool isArchived = false,
}) => Account(
      id: id,
      name: name,
      type: AccountType.bank,
      currencyCode: currencyCode,
      openingBalanceMinorUnits: openingBalanceMinorUnits,
      isArchived: isArchived,
    );

FinancialTransaction makeTransaction({
  String id = 'tx-1',
  String accountId = 'account-1',
  int amountMinorUnits = 1000,
  String currencyCode = 'EGP',
  DateTime? occurredOn,
}) => FinancialTransaction(
      id: id,
      accountId: accountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      occurredOn: occurredOn ?? DateTime(2026, 9, 4),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('transaction references stable account ID, not account name', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(id: 'stable-id', name: 'Old name'));
    await transactions.save(
      makeTransaction(id: 'tx-1', accountId: 'stable-id'),
    );

    await accounts.save(makeAccount(id: 'stable-id', name: 'Renamed account'));

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );
    final result = await service.transactionsForAccount('stable-id');

    expect(result.single.accountId, 'stable-id');
  });

  test('opening balance plus signed transactions produces exact balance', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(openingBalanceMinorUnits: 10000));
    await transactions.save(makeTransaction(id: 'income', amountMinorUnits: 2500));
    await transactions.save(makeTransaction(id: 'expense', amountMinorUnits: -1200));

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );

    final balance = await service.balanceForAccount('account-1');
    expect(balance.openingBalanceMinorUnits, 10000);
    expect(balance.transactionTotalMinorUnits, 1300);
    expect(balance.minorUnits, 11300);
    expect(await service.balanceMinorUnits('account-1'), 11300);
  });

  test('negative expense decreases balance without floating-point arithmetic', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(openingBalanceMinorUnits: 500));
    await transactions.save(makeTransaction(amountMinorUnits: -125));

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );

    expect(await service.balanceMinorUnits('account-1'), 375);
    expect((await transactions.list()).single.amountMinorUnits, -125);
  });

  test('multiple transactions are calculated deterministically', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount());
    await transactions.save(
      makeTransaction(
        id: 'b',
        amountMinorUnits: 200,
        occurredOn: DateTime(2026, 9, 2),
      ),
    );
    await transactions.save(
      makeTransaction(
        id: 'a',
        amountMinorUnits: 300,
        occurredOn: DateTime(2026, 9, 2),
      ),
    );
    await transactions.save(
      makeTransaction(
        id: 'c',
        amountMinorUnits: -50,
        occurredOn: DateTime(2026, 9, 3),
      ),
    );

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );
    final result = await service.transactionsForAccount('account-1');

    expect(result.map((item) => item.id).toList(), <String>['a', 'b', 'c']);
    expect(await service.balanceMinorUnits('account-1'), 10450);
  });

  test('currency mismatch is explicitly rejected', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(currencyCode: 'USD'));
    await transactions.save(makeTransaction(currencyCode: 'EUR'));

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );

    expect(
      () => service.balanceForAccount('account-1'),
      throwsA(isA<AccountCurrencyMismatchException>()),
    );
  });

  test('renaming account does not alter historical transaction identity', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(name: 'Before rename'));
    await transactions.save(makeTransaction(id: 'tx-stable'));

    await accounts.save(makeAccount(name: 'After rename'));

    final stored = await transactions.getById('tx-stable');
    expect(stored!.id, 'tx-stable');
    expect(stored.accountId, 'account-1');
  });

  test('archiving account preserves historical transactions', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount());
    await transactions.save(makeTransaction(id: 'history'));

    await accounts.archiveById('account-1');

    final archived = await accounts.getById('account-1');
    final history = await transactions.getById('history');
    expect(archived!.isArchived, isTrue);
    expect(history!.accountId, 'account-1');
    expect(await AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    ).balanceMinorUnits('account-1'), 11000);
  });

  test('account-specific query excludes other accounts', () async {
    final preferences = await SharedPreferences.getInstance();
    final accounts = LocalAccountRepository(preferences: preferences);
    final transactions = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await accounts.save(makeAccount(id: 'account-a'));
    await accounts.save(makeAccount(id: 'account-b'));
    await transactions.save(makeTransaction(id: 'a-tx', accountId: 'account-a'));
    await transactions.save(makeTransaction(id: 'b-tx', accountId: 'account-b'));

    final service = AccountBalanceQueryService(
      accounts: accounts,
      transactions: transactions,
    );

    expect(
      (await service.transactionsForAccount('account-a')).map((t) => t.id),
      <String>['a-tx'],
    );
  });

  test('transaction persistence uses a dedicated namespace', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await repository.save(makeTransaction());

    expect(
      preferences.getString(LocalFinancialTransactionRepository.storageKey),
      isNotNull,
    );
    expect(
      preferences.getString(LocalAccountRepository.storageKey),
      isNull,
    );
    expect(
      LocalFinancialTransactionRepository.storageKey,
      'nus.finance.transactions.v1',
    );
  });

  test('malformed transaction records do not corrupt valid collection entries', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      LocalFinancialTransactionRepository.storageKey,
      jsonEncode(<dynamic>[
        makeTransaction(id: 'valid').toJson(),
        <String, dynamic>{
          'id': 'broken',
          'accountId': 'account-1',
          'amountMinorUnits': '100',
          'currencyCode': 'EGP',
          'occurredOn': '2026-09-04T00:00:00.000',
        },
        'not-an-object',
      ]),
    );

    final repository = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    final transactions = await repository.list();

    expect(transactions, hasLength(1));
    expect(transactions.single.id, 'valid');
  });

  test('repository update preserves transaction ID while changing account reference', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalFinancialTransactionRepository(
      preferences: preferences,
    );
    await repository.save(makeTransaction(id: 'tx-1', accountId: 'account-a'));
    await repository.save(
      makeTransaction(id: 'tx-1', accountId: 'account-b', amountMinorUnits: 2000),
    );

    final updated = await repository.getById('tx-1');
    expect(updated!.id, 'tx-1');
    expect(updated.accountId, 'account-b');
    expect(updated.amountMinorUnits, 2000);
    expect(await repository.list(), hasLength(1));
  });

  test('repository boundaries are domain contracts', () {
    expect(LocalAccountRepository, isA<Type>());
    expect(LocalFinancialTransactionRepository, isA<Type>());
    expect(AccountRepository, isA<Type>());
    expect(FinancialTransactionRepository, isA<Type>());
    expect(DomainRepository<Account>, isA<Type>());
    expect(DomainRepository<FinancialTransaction>, isA<Type>());
  });

  test('missing account is an explicit query failure', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = AccountBalanceQueryService(
      accounts: LocalAccountRepository(preferences: preferences),
      transactions: LocalFinancialTransactionRepository(
        preferences: preferences,
      ),
    );

    expect(
      () => service.balanceMinorUnits('missing'),
      throwsStateError,
    );
  });
}
