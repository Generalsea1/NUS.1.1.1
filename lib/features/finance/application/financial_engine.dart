import '../../expenses/application/expense_management_service.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../income/application/income_source_service.dart';
import '../../obligations/application/obligation_service.dart';

class FinancialSnapshot {
  const FinancialSnapshot({
    required this.year,
    required this.month,
    required this.currencyCode,
    required this.monthlyIncome,
    required this.monthlyObligations,
    required this.actualExpensesMinorUnits,
    required this.expectedRecurringExpensesMinorUnits,
    required this.actualPositionMinorUnits,
    required this.positionAfterObligations,
  });

  final int year;
  final int month;
  final String currencyCode;
  final int monthlyIncome;
  final int monthlyObligations;
  final int actualExpensesMinorUnits;
  final int expectedRecurringExpensesMinorUnits;

  /// Actual cash position: authoritative income minus actual expense outflows.
  final int actualPositionMinorUnits;

  /// Committed position: authoritative income minus expected/committed obligations.
  /// It deliberately excludes actual expenses so an obligation/payment pair cannot
  /// be subtracted twice before settlement semantics exist.
  final int positionAfterObligations;

  int get scale => CurrencyRegistry.get(currencyCode).scale;
  int get monthlyIncomeMinorUnits => monthlyIncome * scale;
  int get monthlyObligationsMinorUnits => monthlyObligations * scale;
}

class FinancialEngine {
  const FinancialEngine({
    required IncomeSourceService incomeService,
    required ObligationService obligationService,
    required ExpenseManagementService expenseService,
  })  : _incomeService = incomeService,
        _obligationService = obligationService,
        _expenseService = expenseService;

  final IncomeSourceService _incomeService;
  final ObligationService _obligationService;
  final ExpenseManagementService _expenseService;

  Future<FinancialSnapshot> calculate({
    required String userId,
    required int year,
    required int month,
    required String currencyCode,
  }) async {
    final currency = currencyCode.trim().toUpperCase();
    final metadata = CurrencyRegistry.get(currency);

    final incomeSources = await _incomeService.list(userId);
    final obligations = await _obligationService.list(userId);
    final income = _incomeService.totalMonthlyIncome(
      incomeSources,
      currencyCode: currency,
    );
    final obligationsTotal = _obligationService.totalMonthlyObligations(
      obligations,
      currencyCode: currency,
    );

    final actualExpenses = await _expenseService.monthlyActualTotal(
      year: year,
      month: month,
      currencyCode: currency,
    );
    final expectedRecurring = await _expenseService.monthlyExpectedRecurringTotal(
      year: year,
      month: month,
      currencyCode: currency,
    );

    final incomeMinor = income * metadata.scale;

    return FinancialSnapshot(
      year: year,
      month: month,
      currencyCode: currency,
      monthlyIncome: income,
      monthlyObligations: obligationsTotal,
      actualExpensesMinorUnits: actualExpenses,
      expectedRecurringExpensesMinorUnits: expectedRecurring,
      actualPositionMinorUnits: incomeMinor - actualExpenses,
      positionAfterObligations: income - obligationsTotal,
    );
  }
}
