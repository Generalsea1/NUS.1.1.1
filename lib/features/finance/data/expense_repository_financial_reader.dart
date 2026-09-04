import '../../expenses/domain/expense.dart';
import '../application/expense_financial_query_service.dart';

/// Adapter from the existing Expense repository boundary into Finance reads.
///
/// This dependency points from Finance infrastructure toward the Expense
/// source and never creates a reverse dependency from Expenses into Finance.
class ExpenseRepositoryFinancialReader implements FinancialExpenseReader {
  const ExpenseRepositoryFinancialReader({required ExpenseRepository repository})
      : _repository = repository;

  final ExpenseRepository _repository;

  @override
  Future<List<FinancialExpenseSnapshot>> readExpenses() async {
    final expenses = await _repository.list();
    return List<FinancialExpenseSnapshot>.unmodifiable(
      expenses.map(_toSnapshot),
    );
  }

  static FinancialExpenseSnapshot _toSnapshot(Expense expense) =>
      FinancialExpenseSnapshot(
        id: expense.id,
        amountMinorUnits: expense.amount.minorUnits,
        currencyCode: expense.amount.currencyCode,
        year: expense.date.year,
        month: expense.date.month,
        day: expense.date.day,
        categoryId: expense.category,
      );
}
