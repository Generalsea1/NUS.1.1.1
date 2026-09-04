import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/domain/financial_transaction.dart';

void main() {
  test('normalizes identity and currency and computes signed cash flow', () {
    final income = FinancialTransaction(
      id: ' income-1 ',
      accountId: ' account-1 ',
      amountMinorUnits: 125050,
      currencyCode: 'usd',
      occurredAt: DateTime(2026, 9, 4, 10),
      type: FinancialTransactionType.income,
      categoryId: ' salary ',
      description: ' Pay ',
      sourceReference: ' source-1 ',
    );

    expect(income.id, 'income-1');
    expect(income.accountId, 'account-1');
    expect(income.amountMinorUnits, 125050);
    expect(income.currencyCode, 'USD');
    expect(income.categoryId, 'salary');
    expect(income.description, 'Pay');
    expect(income.sourceReference, 'source-1');
    expect(income.signedMinorUnits, 125050);

    final expense = FinancialTransaction(
      id: 'expense-1',
      accountId: 'account-1',
      amountMinorUnits: 2500,
      currencyCode: 'EUR',
      occurredAt: DateTime(2026, 9, 4),
      type: FinancialTransactionType.expense,
    );
    expect(expense.signedMinorUnits, -2500);
  });

  test('rejects invalid transaction identity and money shape', () {
    expect(
      () => FinancialTransaction(
        id: ' ',
        accountId: 'account-1',
        amountMinorUnits: 100,
        currencyCode: 'USD',
        occurredAt: DateTime(2026, 9, 4),
        type: FinancialTransactionType.expense,
      ),
      throwsArgumentError,
    );

    expect(
      () => FinancialTransaction(
        id: 'tx-1',
        accountId: ' ',
        amountMinorUnits: 100,
        currencyCode: 'USD',
        occurredAt: DateTime(2026, 9, 4),
        type: FinancialTransactionType.expense,
      ),
      throwsArgumentError,
    );

    expect(
      () => FinancialTransaction(
        id: 'tx-1',
        accountId: 'account-1',
        amountMinorUnits: 0,
        currencyCode: 'USD',
        occurredAt: DateTime(2026, 9, 4),
        type: FinancialTransactionType.expense,
      ),
      throwsArgumentError,
    );

    expect(
      () => FinancialTransaction(
        id: 'tx-1',
        accountId: 'account-1',
        amountMinorUnits: 100,
        currencyCode: 'US',
        occurredAt: DateTime(2026, 9, 4),
        type: FinancialTransactionType.expense,
      ),
      throwsArgumentError,
    );
  });

  test('serializes without provider or UI types', () {
    final transaction = FinancialTransaction(
      id: 'tx-1',
      accountId: 'account-1',
      amountMinorUnits: 999,
      currencyCode: 'USD',
      occurredAt: DateTime(2026, 9, 4, 12, 30),
      type: FinancialTransactionType.expense,
      categoryId: 'food',
    );

    expect(transaction.toJson(), {
      'id': 'tx-1',
      'accountId': 'account-1',
      'amountMinorUnits': 999,
      'currencyCode': 'USD',
      'occurredAt': '2026-09-04T12:30:00.000',
      'type': 'expense',
      'categoryId': 'food',
      'description': null,
      'sourceReference': null,
    });
  });
}
