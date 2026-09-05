import '../domain/budget.dart';
import '../domain/financial_transaction.dart';

class BudgetQueryService {
  const BudgetQueryService({required FinancialTransactionRepository transactions});
  final FinancialTransactionRepository transactions;

  Future<int> consumedMinorUnits(Budget budget) async {
    final all=await transactions.list();
    var total=0;
    for(final tx in all){
      if(tx.accountId.trim().isEmpty) continue;
      if(tx.currencyCode!=budget.currencyCode) continue;
      if(tx.occurredOn.isBefore(budget.periodStart)||tx.occurredOn.isAfter(budget.periodEnd)) continue;
      if(budget.categoryId!=null&&tx.categoryId!=budget.categoryId) continue;
      final qualifies=budget.direction==BudgetDirection.expense?tx.isExpense:tx.isIncome;
      if(!qualifies) continue;
      total+=tx.amountMinorUnits;
    }
    return total;
  }

  Future<bool> isExceeded(Budget budget) async => (await consumedMinorUnits(budget))>budget.limitMinorUnits;
}
