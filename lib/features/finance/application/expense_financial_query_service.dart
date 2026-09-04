/// Read-only financial projection of an Expense record.
///
/// Finance consumes this neutral snapshot instead of importing or mutating
/// the Expense UI/domain through its query logic.
class FinancialExpenseSnapshot {
  const FinancialExpenseSnapshot({
    required this.id,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.year,
    required this.month,
    required this.day,
    this.category,
  });

  final String id;
  final int amountMinorUnits;
  final String currencyCode;
  final int year;
  final int month;
  final int day;

  /// Current Expense representation is a normalized category label.
  /// A future Category aggregate will introduce a stable category ID.
  final String? category;
}

/// Application query boundary for finance consumption of Expense data.
abstract interface class FinancialExpenseReader {
  Future<List<FinancialExpenseSnapshot>> readExpenses();
}

/// Deterministic Expense-backed financial summaries.
class ExpenseFinancialQueryService {
  const ExpenseFinancialQueryService({required FinancialExpenseReader reader})
      : _reader = reader;

  final FinancialExpenseReader _reader;

  Future<int> monthlyExpenseMinorUnits({
    required int year,
    required int month,
    required String currencyCode,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final expenses = await _reader.readExpenses();
    var total = 0;

    for (final expense in expenses) {
      if (expense.year == year &&
          expense.month == month &&
          expense.currencyCode == normalizedCurrency) {
        total += expense.amountMinorUnits;
      }
    }

    return total;
  }

  Future<Map<String, int>> monthlyExpenseMinorUnitsByCategory({
    required int year,
    required int month,
    required String currencyCode,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final expenses = await _reader.readExpenses();
    final totals = <String, int>{};

    for (final expense in expenses) {
      if (expense.year != year ||
          expense.month != month ||
          expense.currencyCode != normalizedCurrency) {
        continue;
      }

      final category = expense.category ?? 'uncategorized';
      totals[category] = (totals[category] ?? 0) + expense.amountMinorUnits;
    }

    final sortedKeys = totals.keys.toList()..sort();
    return <String, int>{
      for (final key in sortedKeys) key: totals[key]!,
    };
  }

  /// Existing Expense records are positive amounts representing outflow.
  int signedExpenseMinorUnits(int expenseMinorUnits) => -expenseMinorUnits;
}
