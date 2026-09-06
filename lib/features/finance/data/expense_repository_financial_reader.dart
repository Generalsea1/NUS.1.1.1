import '../application/expense_financial_query_service.dart';
import '../../expenses/domain/expense.dart';

/// Adapts the Expense repository into the finance read-model boundary.
///
/// Finance never reaches into Expense persistence details; it consumes the
/// neutral [FinancialExpenseSnapshot] contract defined in the application
/// layer. This adapter is intentionally read-only.
class ExpenseRepositoryFinancialReader implements FinancialExpenseReader {
  const ExpenseRepositoryFinancialReader({required ExpenseRepository repository})
      : _repository = repository;

  final ExpenseRepository _repository;

  @override
  Future<List<FinancialExpenseSnapshot>> readExpenses() async {
    final expenses = await _repository.list();
    return <FinancialExpenseSnapshot>[
      for (final expense in expenses)
        FinancialExpenseSnapshot(
          id: expense.id,
          amountMinorUnits: expense.amount.minorUnits,
          currencyCode: expense.amount.currencyCode.trim().toUpperCase(),
          year: expense.date.year,
          month: expense.date.month,
          day: expense.date.day,
          category: expense.category,
        ),
    ];
  }
}
