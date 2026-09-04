import '../domain/account.dart';
import '../domain/financial_transaction.dart';

/// Thrown when a transaction currency differs from its account currency.
class AccountCurrencyMismatchException implements Exception {
  const AccountCurrencyMismatchException({
    required this.accountId,
    required this.accountCurrencyCode,
    required this.transactionId,
    required this.transactionCurrencyCode,
  });

  final String accountId;
  final String accountCurrencyCode;
  final String transactionId;
  final String transactionCurrencyCode;

  @override
  String toString() =>
      'AccountCurrencyMismatchException(accountId: $accountId, '
      'accountCurrencyCode: $accountCurrencyCode, transactionId: $transactionId, '
      'transactionCurrencyCode: $transactionCurrencyCode)';
}

/// Read-only balance derived from opening balance and transaction history.
class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.currencyCode,
    required this.openingBalanceMinorUnits,
    required this.transactionTotalMinorUnits,
  });

  final String accountId;
  final String currencyCode;
  final int openingBalanceMinorUnits;
  final int transactionTotalMinorUnits;

  int get minorUnits => openingBalanceMinorUnits + transactionTotalMinorUnits;
}

/// Deterministically derives account balances without storing mutable balance state.
class AccountBalanceQueryService {
  const AccountBalanceQueryService({
    required AccountRepository accounts,
    required FinancialTransactionRepository transactions,
  })  : _accounts = accounts,
        _transactions = transactions;

  final AccountRepository _accounts;
  final FinancialTransactionRepository _transactions;

  Future<AccountBalance> balanceForAccount(String accountId) async {
    final account = await _requireAccount(accountId);
    final accountTransactions = await transactionsForAccount(account.id);

    var transactionTotalMinorUnits = 0;
    for (final transaction in accountTransactions) {
      _validateCurrency(account, transaction);
      transactionTotalMinorUnits += transaction.amountMinorUnits;
    }

    return AccountBalance(
      accountId: account.id,
      currencyCode: account.currencyCode,
      openingBalanceMinorUnits: account.openingBalanceMinorUnits,
      transactionTotalMinorUnits: transactionTotalMinorUnits,
    );
  }

  Future<int> balanceMinorUnits(String accountId) async =>
      (await balanceForAccount(accountId)).minorUnits;

  Future<List<FinancialTransaction>> transactionsForAccount(
    String accountId,
  ) async {
    final account = await _requireAccount(accountId);
    final transactions = await _transactions.list();
    final matching = <FinancialTransaction>[];

    for (final transaction in transactions) {
      if (transaction.accountId != account.id) continue;
      _validateCurrency(account, transaction);
      matching.add(transaction);
    }

    matching.sort((a, b) {
      final byDate = a.occurredOn.compareTo(b.occurredOn);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });

    return List<FinancialTransaction>.unmodifiable(matching);
  }

  Future<Account> _requireAccount(String accountId) async {
    final cleanId = accountId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Account ID must not be empty.',
      );
    }

    final account = await _accounts.getById(cleanId);
    if (account == null) {
      throw StateError('Account not found: $cleanId');
    }
    return account;
  }

  static void _validateCurrency(
    Account account,
    FinancialTransaction transaction,
  ) {
    if (account.currencyCode != transaction.currencyCode) {
      throw AccountCurrencyMismatchException(
        accountId: account.id,
        accountCurrencyCode: account.currencyCode,
        transactionId: transaction.id,
        transactionCurrencyCode: transaction.currencyCode,
      );
    }
  }
}
