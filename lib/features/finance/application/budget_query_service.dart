import '../domain/budget.dart';
import '../domain/financial_transaction.dart';

/// Derives budget consumption from ledger transactions without storing a
/// mutable spent counter on the Budget aggregate.
class BudgetQueryService {
  const BudgetQueryService({required this.transactions});

  final FinancialTransactionRepository transactions;

  Future<int> consumedMinorUnits(Budget budget) async {
    final all = await transactions.list();
    var total = 0;
    for (final transaction in all) {
      if (transaction.currencyCode != budget.currencyCode) continue;
      if (transaction.occurredOn.isBefore(budget.periodStart) ||
          !transaction.occurredOn.isBefore(budget.periodEnd)) {
        continue;
      }
      if (budget.categoryId != null &&
          transaction.categoryId != budget.categoryId) {
        continue;
      }

      if (budget.direction == BudgetDirection.expense) {
        if (!transaction.isExpense) continue;
        total += -transaction.amountMinorUnits;
      } else {
        if (!transaction.isIncome) continue;
        total += transaction.amountMinorUnits;
      }
    }
    return total;
  }

  Future<int> remainingMinorUnits(Budget budget) async =>
      budget.limitMinorUnits - await consumedMinorUnits(budget);

  Future<bool> isExceeded(Budget budget) async =>
      (await consumedMinorUnits(budget)) > budget.limitMinorUnits;
}
