import '../domain/account.dart';
import '../domain/financial_transaction.dart';

class FinancialSummaryCurrencyMismatchException implements Exception {
  const FinancialSummaryCurrencyMismatchException({required this.currency, required this.otherCurrency});
  final String currency;
  final String otherCurrency;
}

class FinancialPeriodSummary {
  const FinancialPeriodSummary({required this.currencyCode, required this.incomeMinorUnits, required this.expenseMinorUnits, required this.netCashFlowMinorUnits});
  final String currencyCode;
  final int incomeMinorUnits;
  final int expenseMinorUnits;
  final int netCashFlowMinorUnits;
}

class FinancialCategorySummary {
  const FinancialCategorySummary({required this.categoryId, required this.currencyCode, required this.amountMinorUnits});
  final String categoryId;
  final String currencyCode;
  final int amountMinorUnits;
}

class FinancialTrendPoint {
  const FinancialTrendPoint({required this.periodStart, required this.currencyCode, required this.incomeMinorUnits, required this.expenseMinorUnits, required this.netCashFlowMinorUnits});
  final DateTime periodStart;
  final String currencyCode;
  final int incomeMinorUnits;
  final int expenseMinorUnits;
  final int netCashFlowMinorUnits;
}

/// Read-only financial reporting boundary. Nothing returned here is persisted.
class FinancialSummaryQueryService {
  const FinancialSummaryQueryService({required FinancialTransactionRepository transactionRepository, required AccountRepository accountRepository})
      : _transactionRepository = transactionRepository, _accountRepository = accountRepository;

  final FinancialTransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;

  Future<FinancialPeriodSummary> periodSummary({required String currencyCode, required DateTime start, required DateTime end}) async {
    final currency = currencyCode.trim().toUpperCase();
    _validateCurrency(currency);
    if (!end.isAfter(start)) throw ArgumentError.value(end, 'end', 'End must be after start.');
    var income = 0;
    var expense = 0;
    for (final transaction in await _transactionsFor(currency, start, end)) {
      if (transaction.amountMinorUnits > 0) {
        income += transaction.amountMinorUnits;
      } else {
        expense += -transaction.amountMinorUnits;
      }
    }
    return FinancialPeriodSummary(currencyCode: currency, incomeMinorUnits: income, expenseMinorUnits: expense, netCashFlowMinorUnits: income - expense);
  }

  Future<List<FinancialCategorySummary>> categorySpending({required String currencyCode, required DateTime start, required DateTime end}) async {
    final currency = currencyCode.trim().toUpperCase();
    _validateCurrency(currency);
    final totals = <String, int>{};
    for (final transaction in await _transactionsFor(currency, start, end)) {
      if (transaction.amountMinorUnits >= 0 || transaction.categoryId == null) continue;
      final categoryId = transaction.categoryId!;
      totals[categoryId] = (totals[categoryId] ?? 0) - transaction.amountMinorUnits;
    }
    final result = totals.entries.map((entry) => FinancialCategorySummary(categoryId: entry.key, currencyCode: currency, amountMinorUnits: entry.value)).toList();
    result.sort((a, b) => a.categoryId.compareTo(b.categoryId));
    return List.unmodifiable(result);
  }

  Future<int> accountBalance(String accountId) async {
    final account = await _accountRepository.getById(accountId.trim());
    if (account == null) return 0;
    var balance = account.openingBalanceMinorUnits;
    for (final transaction in await _transactionRepository.list()) {
      if (transaction.accountId != account.id) continue;
      if (transaction.currencyCode != account.currencyCode) {
        throw FinancialSummaryCurrencyMismatchException(currency: account.currencyCode, otherCurrency: transaction.currencyCode);
      }
      balance += transaction.amountMinorUnits;
    }
    return balance;
  }

  Future<List<FinancialTrendPoint>> monthlyTrend({required String currencyCode, required DateTime firstMonth, required int monthCount}) async {
    final currency = currencyCode.trim().toUpperCase();
    _validateCurrency(currency);
    if (monthCount <= 0) throw ArgumentError.value(monthCount, 'monthCount', 'Must be positive.');
    final all = await _transactionRepository.list();
    final points = <FinancialTrendPoint>[];
    for (var i = 0; i < monthCount; i++) {
      final start = DateTime(firstMonth.year, firstMonth.month + i);
      final end = DateTime(start.year, start.month + 1);
      var income = 0;
      var expense = 0;
      for (final transaction in all) {
        if (transaction.currencyCode != currency) continue;
        if (!transaction.occurredOn.isBefore(start) && transaction.occurredOn.isBefore(end)) {
          if (transaction.amountMinorUnits > 0) income += transaction.amountMinorUnits;
          if (transaction.amountMinorUnits < 0) expense -= transaction.amountMinorUnits;
        }
      }
      points.add(FinancialTrendPoint(periodStart: start, currencyCode: currency, incomeMinorUnits: income, expenseMinorUnits: expense, netCashFlowMinorUnits: income - expense));
    }
    return List.unmodifiable(points);
  }

  Future<List<FinancialTransaction>> _transactionsFor(String currency, DateTime start, DateTime end) async {
    return (await _transactionRepository.list()).where((transaction) => transaction.currencyCode == currency && !transaction.occurredOn.isBefore(start) && transaction.occurredOn.isBefore(end)).toList(growable: false);
  }

  static void _validateCurrency(String currency) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) throw ArgumentError.value(currency, 'currencyCode', 'Currency must be exactly three letters.');
  }
}
