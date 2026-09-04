import '../domain/account.dart';
import '../domain/financial_transaction.dart';

/// Raised when a create operation reuses an existing transaction ID.
class DuplicateFinancialTransactionException implements Exception {
  const DuplicateFinancialTransactionException(this.transactionId);

  final String transactionId;

  @override
  String toString() =>
      'DuplicateFinancialTransactionException(transactionId: $transactionId)';
}

/// Raised when a transaction targets an archived account during creation.
class ArchivedAccountMutationException implements Exception {
  const ArchivedAccountMutationException(this.accountId);

  final String accountId;

  @override
  String toString() =>
      'ArchivedAccountMutationException(accountId: $accountId)';
}

/// Raised when a transaction currency differs from its account currency.
class FinancialTransactionCurrencyMismatchException implements Exception {
  const FinancialTransactionCurrencyMismatchException({
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
      'FinancialTransactionCurrencyMismatchException('
      'accountId: $accountId, accountCurrencyCode: $accountCurrencyCode, '
      'transactionId: $transactionId, '
      'transactionCurrencyCode: $transactionCurrencyCode)';
}

/// Application boundary for controlled Finance transaction mutations.
///
/// This service owns account relationship, currency, active-account and
/// duplicate-ID validation. Persistence remains behind repository ports.
class FinancialTransactionMutationService {
  const FinancialTransactionMutationService({
    required AccountRepository accounts,
    required FinancialTransactionRepository transactions,
  })  : _accounts = accounts,
        _transactions = transactions;

  final AccountRepository _accounts;
  final FinancialTransactionRepository _transactions;

  /// Creates a new transaction after validating its account relationship.
  Future<FinancialTransaction> createTransaction({
    required String id,
    required String accountId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime occurredOn,
    String? categoryId,
    String? counterparty,
    String? note,
    String? externalReference,
  }) async {
    final transaction = FinancialTransaction(
      id: id,
      accountId: accountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      occurredOn: occurredOn,
      categoryId: categoryId,
      counterparty: counterparty,
      note: note,
      externalReference: externalReference,
    );

    final account = await _requireAccount(transaction.accountId);
    _ensureAccountActive(account);
    _ensureCurrencyCompatible(account, transaction);

    final existing = await _transactions.getById(transaction.id);
    if (existing != null) {
      throw DuplicateFinancialTransactionException(transaction.id);
    }

    await _transactions.save(transaction);
    return transaction;
  }

  /// Updates an existing transaction without changing its identity or account.
  Future<FinancialTransaction> updateTransaction(
    FinancialTransaction transaction,
  ) async {
    final existing = await _transactions.getById(transaction.id);
    if (existing == null) {
      throw StateError('Financial transaction not found: ${transaction.id}');
    }

    if (existing.accountId != transaction.accountId) {
      throw ArgumentError.value(
        transaction.accountId,
        'accountId',
        'Transaction account cannot change through updateTransaction.',
      );
    }

    final account = await _requireAccount(transaction.accountId);
    _ensureCurrencyCompatible(account, transaction);
    await _transactions.save(transaction);
    return transaction;
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

  static void _ensureAccountActive(Account account) {
    if (account.isArchived) {
      throw ArchivedAccountMutationException(account.id);
    }
  }

  static void _ensureCurrencyCompatible(
    Account account,
    FinancialTransaction transaction,
  ) {
    if (account.currencyCode != transaction.currencyCode) {
      throw FinancialTransactionCurrencyMismatchException(
        accountId: account.id,
        accountCurrencyCode: account.currencyCode,
        transactionId: transaction.id,
        transactionCurrencyCode: transaction.currencyCode,
      );
    }
  }
}
