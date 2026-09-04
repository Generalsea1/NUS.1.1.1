import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/core/domain/domain_entity.dart';
import 'package:nus/core/domain/domain_repository.dart';
import 'package:nus/features/finance/data/local_account_repository.dart';
import 'package:nus/features/finance/domain/account.dart';

Account makeAccount({
  String id = 'account-1',
  String name = 'Main bank',
  AccountType type = AccountType.bank,
  String currencyCode = 'egp',
  int openingBalanceMinorUnits = 125000,
  bool isArchived = false,
}) => Account(
      id: id,
      name: name,
      type: type,
      currencyCode: currencyCode,
      openingBalanceMinorUnits: openingBalanceMinorUnits,
      isArchived: isArchived,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Account creation normalizes identity fields and preserves exact balance', () {
    final account = makeAccount(
      id: '  account-1  ',
      name: '  Main bank  ',
      currencyCode: 'egp',
      openingBalanceMinorUnits: 123456789,
    );

    expect(account.id, 'account-1');
    expect(account.name, 'Main bank');
    expect(account.currencyCode, 'EGP');
    expect(account.openingBalanceMinorUnits, 123456789);
    expect(account.isArchived, isFalse);
    expect(account, isA<DomainEntity>());
  });

  test('stable ID is preserved by copy and update', () {
    final original = makeAccount();
    final updated = original.copyWith(name: 'Updated bank');

    expect(updated.id, original.id);
    expect(updated.name, 'Updated bank');
  });

  test('account type supports bank, wallet and cash', () {
    expect(makeAccount(type: AccountType.bank).type, AccountType.bank);
    expect(makeAccount(type: AccountType.wallet).type, AccountType.wallet);
    expect(makeAccount(type: AccountType.cash).type, AccountType.cash);
  });

  test('currency code must be exactly three alphabetic characters', () {
    expect(
      () => makeAccount(currencyCode: 'US'),
      throwsArgumentError,
    );
    expect(
      () => makeAccount(currencyCode: 'USDX'),
      throwsArgumentError,
    );
    expect(
      () => makeAccount(currencyCode: '1EG'),
      throwsArgumentError,
    );
  });

  test('required account identity cannot be empty', () {
    expect(() => makeAccount(id: '   '), throwsArgumentError);
    expect(() => makeAccount(name: '   '), throwsArgumentError);
  });

  test('serialization is deterministic and round-trips exactly', () {
    final account = makeAccount(
      id: 'account-2',
      name: 'Cash wallet',
      type: AccountType.wallet,
      currencyCode: 'usd',
      openingBalanceMinorUnits: -42,
      isArchived: true,
    );

    final first = jsonEncode(account.toJson());
    final second = jsonEncode(account.toJson());
    final restored = Account.fromJson(account.toJson());

    expect(first, second);
    expect(restored, account);
    expect(account.toJson(), <String, dynamic>{
      'id': 'account-2',
      'name': 'Cash wallet',
      'type': 'wallet',
      'currencyCode': 'USD',
      'openingBalanceMinorUnits': -42,
      'isArchived': true,
    });
  });

  test('invalid persisted numeric money is rejected', () {
    expect(
      () => Account.fromJson(<String, dynamic>{
        ...makeAccount().toJson(),
        'openingBalanceMinorUnits': 12.5,
      }),
      throwsFormatException,
    );
  });

  test('repository follows the domain repository boundary', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalAccountRepository(preferences: preferences);

    expect(repository, isA<DomainRepository<Account>>());
    expect(repository, isA<AccountRepository>());
  });

  test('repository persists, retrieves, updates and lists accounts locally', () async {
    final repository = LocalAccountRepository();
    final account = makeAccount(id: 'b-account');
    final second = makeAccount(id: 'a-account', type: AccountType.cash);

    await repository.save(account);
    await repository.save(second);

    expect(await repository.getById('b-account'), account);
    expect(
      (await repository.list()).map((item) => item.id).toList(),
      <String>['a-account', 'b-account'],
    );

    await repository.save(
      account.copyWith(
        name: 'Updated',
        openingBalanceMinorUnits: 999,
      ),
    );
    final updated = await repository.getById('b-account');

    expect(updated!.id, 'b-account');
    expect(updated.name, 'Updated');
    expect(updated.openingBalanceMinorUnits, 999);
    expect((await repository.list()).length, 2);
  });

  test('archive preserves account identity and deleteById uses archive semantics', () async {
    final repository = LocalAccountRepository();
    await repository.save(makeAccount(id: 'account-3'));

    await repository.archiveById('account-3');
    var archived = await repository.getById('account-3');
    expect(archived, isNotNull);
    expect(archived!.id, 'account-3');
    expect(archived.isArchived, isTrue);

    await repository.deleteById('account-3');
    archived = await repository.getById('account-3');
    expect(archived, isNotNull);
    expect(archived!.isArchived, isTrue);
  });

  test('repository isolates malformed individual records', () async {
    final valid = makeAccount(id: 'valid').toJson();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      LocalAccountRepository.storageKey,
      jsonEncode(<dynamic>[
        valid,
        <String, dynamic>{
          'id': 'broken',
          'name': 'Broken',
          'type': 'not-supported',
          'currencyCode': 'EGP',
          'openingBalanceMinorUnits': 100,
          'isArchived': false,
        },
        'not-an-object',
      ]),
    );

    final repository = LocalAccountRepository(preferences: preferences);
    final accounts = await repository.list();

    expect(accounts, hasLength(1));
    expect(accounts.single.id, 'valid');
  });

  test('repository isolates duplicate IDs deterministically', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      LocalAccountRepository.storageKey,
      jsonEncode(<dynamic>[
        makeAccount(id: 'same', name: 'First').toJson(),
        makeAccount(id: 'same', name: 'Second').toJson(),
      ]),
    );

    final repository = LocalAccountRepository(preferences: preferences);
    final accounts = await repository.list();

    expect(accounts, hasLength(1));
    expect(accounts.single.name, 'First');
  });

  test('local account storage is isolated in its dedicated namespace', () async {
    final preferences = await SharedPreferences.getInstance();
    await LocalAccountRepository(preferences: preferences).save(makeAccount());

    expect(
      preferences.getString(LocalAccountRepository.storageKey),
      isNotNull,
    );
    expect(preferences.getString('nus.expenses.v1'), isNull);
    expect(
      LocalAccountRepository.storageKey,
      isNot('nus.expenses.v1'),
    );
  });

  test('malformed storage root is safe for reads and explicit for writes', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(LocalAccountRepository.storageKey, '{bad json');
    final repository = LocalAccountRepository(preferences: preferences);

    expect(await repository.list(), isEmpty);
    expect(
      () => repository.save(makeAccount()),
      throwsFormatException,
    );
  });
}
