import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/financial_transaction_mutation_service.dart';
import 'package:nus/features/finance/application/income_capture_service.dart';
import 'package:nus/features/finance/domain/account.dart';
import 'package:nus/features/finance/domain/financial_category.dart';
import 'package:nus/features/finance/domain/financial_transaction.dart';

void main() {
  final account = Account(
    id: 'account-1',
    name: 'Main',
    type: AccountType.bank,
    currencyCode: 'USD',
    openingBalanceMinorUnits: 10000,
  );
  final incomeCategory = FinancialCategory(
    id: 'income-salary',
    name: 'Salary',
    direction: FinancialCategoryDirection.income,
  );
  final expenseCategory = FinancialCategory(
    id: 'expense-food',
    name: 'Food',
    direction: FinancialCategoryDirection.expense,
  );

  late FakeAccountRepository accounts;
  late FakeTransactionRepository transactions;
  late FakeCategoryRepository categories;
  late IncomeCaptureService service;

  setUp(() {
    accounts = FakeAccountRepository(account);
    transactions = FakeTransactionRepository();
    categories = FakeCategoryRepository(<FinancialCategory>[
      incomeCategory,
      expenseCategory,
    ]);
    service = IncomeCaptureService(
      transactionMutations: FinancialTransactionMutationService(
        accounts: accounts,
        transactions: transactions,
      ),
      categoryRepository: categories,
    );
  });

  test('records a positive income through the transaction mutation boundary', () async {
    final result = await service.recordIncome(
      id: 'income-1',
      accountId: 'account-1',
      amountMinorUnits: 2500,
      currencyCode: 'usd',
      occurredOn: DateTime(2026, 9, 5),
      categoryId: 'income-salary',
      externalReference: 'payroll-1',
    );

    expect(result.amountMinorUnits, 2500);
    expect(result.isIncome, isTrue);
    expect(result.accountId, 'account-1');
    expect(result.currencyCode, 'USD');
    expect(result.categoryId, 'income-salary');
    expect(result.externalReference, 'payroll-1');
    expect(transactions.saved.single, result);
  });

  test('rejects zero or negative income without persistence', () async {
    expect(
      () => service.recordIncome(
        id: 'income-1',
        accountId: 'account-1',
        amountMinorUnits: 0,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(transactions.saved, isEmpty);
  });

  test('rejects an unknown category', () async {
    expect(
      () => service.recordIncome(
        id: 'income-1',
        accountId: 'account-1',
        amountMinorUnits: 1000,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
        categoryId: 'missing',
      ),
      throwsA(isA<StateError>()),
    );
    expect(transactions.saved, isEmpty);
  });

  test('rejects an expense category for income', () async {
    expect(
      () => service.recordIncome(
        id: 'income-1',
        accountId: 'account-1',
        amountMinorUnits: 1000,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
        categoryId: 'expense-food',
      ),
      throwsA(isA<StateError>()),
    );
    expect(transactions.saved, isEmpty);
  });

  test('rejects archived income category', () async {
    categories.values[0] = incomeCategory.archive();
    expect(
      () => service.recordIncome(
        id: 'income-1',
        accountId: 'account-1',
        amountMinorUnits: 1000,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
        categoryId: 'income-salary',
      ),
      throwsA(isA<StateError>()),
    );
    expect(transactions.saved, isEmpty);
  });

  test('does not bypass account and currency validation', () async {
    expect(
      () => service.recordIncome(
        id: 'income-1',
        accountId: 'missing-account',
        amountMinorUnits: 1000,
        currencyCode: 'USD',
        occurredOn: DateTime(2026, 9, 5),
      ),
      throwsA(isA<StateError>()),
    );

    expect(
      () => service.recordIncome(
        id: 'income-2',
        accountId: 'account-1',
        amountMinorUnits: 1000,
        currencyCode: 'EUR',
        occurredOn: DateTime(2026, 9, 5),
      ),
      throwsA(isA<FinancialTransactionCurrencyMismatchException>()),
    );
    expect(transactions.saved, isEmpty);
  });
}

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository(this.value);

  Account? value;

  @override
  Future<void> archiveById(String id) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<Account?> getById(String id) async => value?.id == id ? value : null;

  @override
  Future<List<Account>> list() async => value == null ? const [] : [value!];

  @override
  Future<void> save(Account entity) async => value = entity;
}

class FakeTransactionRepository implements FinancialTransactionRepository {
  final List<FinancialTransaction> saved = [];

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<FinancialTransaction?> getById(String id) async {
    for (final transaction in saved) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<List<FinancialTransaction>> list() async => List.unmodifiable(saved);

  @override
  Future<void> save(FinancialTransaction entity) async {
    saved.removeWhere((item) => item.id == entity.id);
    saved.add(entity);
  }
}

class FakeCategoryRepository implements FinancialCategoryRepository {
  FakeCategoryRepository(this.values);

  final List<FinancialCategory> values;

  @override
  Future<void> archiveById(String id) async {
    final index = values.indexWhere((item) => item.id == id);
    if (index >= 0) values[index] = values[index].archive();
  }

  @override
  Future<void> deleteById(String id) => archiveById(id);

  @override
  Future<FinancialCategory?> getById(String id) async {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }

  @override
  Future<List<FinancialCategory>> list() async => List.unmodifiable(values);

  @override
  Future<void> save(FinancialCategory entity) async {
    values.removeWhere((item) => item.id == entity.id);
    values.add(entity);
  }
}
