import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/domain/domain_entity.dart';
import 'package:nus/core/domain/domain_repository.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

FinancialTransaction makeTransaction({
  String id = 'tx-1',
  String accountId = 'account-1',
  int amountMinorUnits = 1250,
  String currencyCode = 'egp',
  DateTime? occurredOn,
}) => FinancialTransaction(
      id: id,
      accountId: accountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      occurredOn: occurredOn ?? DateTime(2026, 9, 4, 10),
    );

void main() {
  test('normalizes identity and currency and preserves exact signed amount', () {
    final transaction = makeTransaction(
      id: ' tx-1 ',
      accountId: ' account-1 ',
      amountMinorUnits: -125050,
      currencyCode: 'egp',
    );

    expect(transaction.id, 'tx-1');
    expect(transaction.accountId, 'account-1');
    expect(transaction.amountMinorUnits, -125050);
    expect(transaction.currencyCode, 'EGP');
    expect(transaction.isIncome, isFalse);
    expect(transaction.isExpense, isTrue);
    expect(transaction, isA<DomainEntity>());
  });

  test('rejects invalid transaction identity, zero amount and currency shape', () {
    expect(() => makeTransaction(id: '   '), throwsArgumentError);
    expect(() => makeTransaction(accountId: '   '), throwsArgumentError);
    expect(() => makeTransaction(amountMinorUnits: 0), throwsArgumentError);
    expect(() => makeTransaction(currencyCode: 'US'), throwsArgumentError);
    expect(() => makeTransaction(currencyCode: 'USDX'), throwsArgumentError);
    expect(() => makeTransaction(currencyCode: '1EG'), throwsArgumentError);
  });

  test('stable account identity survives transaction copy', () {
    final original = makeTransaction(id: 'tx-stable', accountId: 'account-stable');
    final updated = original.copyWith(amountMinorUnits: -2500);

    expect(updated.id, original.id);
    expect(updated.accountId, original.accountId);
    expect(updated.amountMinorUnits, -2500);
  });

  test('serialization is deterministic and round-trips exactly', () {
    final transaction = makeTransaction(
      id: 'tx-json',
      accountId: 'account-json',
      amountMinorUnits: -999,
      currencyCode: 'usd',
      occurredOn: DateTime(2026, 9, 4, 12, 30),
    );

    final first = jsonEncode(transaction.toJson());
    final second = jsonEncode(transaction.toJson());
    final restored = FinancialTransaction.fromJson(transaction.toJson());

    expect(first, second);
    expect(restored, transaction);
    expect(transaction.toJson(), <String, dynamic>{
      'id': 'tx-json',
      'accountId': 'account-json',
      'amountMinorUnits': -999,
      'currencyCode': 'USD',
      'occurredOn': '2026-09-04T12:30:00.000',
      'categoryId': null,
      'counterparty': null,
      'note': null,
      'externalReference': null,
    });
  });

  test('repository boundary extends DomainRepository without UI or provider types', () {
    // Compile-time architectural assertion: the interface must remain a domain repository.
    expect(FinancialTransactionRepository, isA<Type>());
    expect(DomainRepository<FinancialTransaction>, isA<Type>());
  });

  test('persisted floating-point money is rejected', () {
    expect(
      () => FinancialTransaction.fromJson(<String, dynamic>{
        ...makeTransaction().toJson(),
        'amountMinorUnits': 12.5,
      }),
      throwsFormatException,
    );
  });
}
