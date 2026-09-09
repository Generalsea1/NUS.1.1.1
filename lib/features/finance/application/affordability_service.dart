import '../../expenses/domain/currency_registry.dart';
import 'financial_engine.dart';
import '../domain/affordability.dart';

/// Read-only affordability calculation. It never persists a purchase,
/// payment, debt, installment, or expense.
class AffordabilityService {
  const AffordabilityService({required FinancialEngine financialEngine})
      : _financialEngine = financialEngine;

  final FinancialEngine _financialEngine;

  Future<AffordabilityAssessment> assess({
    required String userId,
    required int year,
    required int month,
    required String currencyCode,
    required int proposedMinorUnits,
    required bool recurring,
    int scenarioMonths = 1,
  }) async {
    if (proposedMinorUnits <= 0) {
      throw ArgumentError.value(
        proposedMinorUnits,
        'proposedMinorUnits',
        'The proposed amount must be greater than zero.',
      );
    }
    if (scenarioMonths < 1 || scenarioMonths > 12) {
      throw ArgumentError.value(
        scenarioMonths,
        'scenarioMonths',
        'Scenario horizon must be between 1 and 12 months.',
      );
    }

    final currency = currencyCode.trim().toUpperCase();
    final metadata = CurrencyRegistry.get(currency);
    final snapshot = await _financialEngine.calculate(
      userId: userId,
      year: year,
      month: month,
      currencyCode: currency,
    );

    final incomeMinor = snapshot.monthlyIncomeMinorUnits;
    final obligationMinor = snapshot.monthlyObligationsMinorUnits;
    final availableBeforeProposal =
        incomeMinor - obligationMinor - snapshot.actualExpensesMinorUnits;

    final resulting = availableBeforeProposal - proposedMinorUnits;
    final horizon = recurring ? scenarioMonths : 1;

    // Deterministic stress scenario only: it repeats the current month's
    // supplied facts and the recurring proposal for the chosen horizon. It is
    // deliberately not a prediction of future income or spending behavior.
    final minimumProjected = horizon == 1
        ? resulting
        : List<int>.generate(
            horizon,
            (_) => availableBeforeProposal - proposedMinorUnits,
          ).reduce((a, b) => a < b ? a : b);

    final status = minimumProjected < 0
        ? AffordabilityStatus.notAffordable
        : minimumProjected < incomeMinor ~/ 10
            ? AffordabilityStatus.pressure
            : AffordabilityStatus.affordable;

    return AffordabilityAssessment(
      status: status,
      currencyCode: metadata.code,
      proposedMinorUnits: proposedMinorUnits,
      monthlyIncomeMinorUnits: incomeMinor,
      monthlyObligationsMinorUnits: obligationMinor,
      existingActualExpensesMinorUnits: snapshot.actualExpensesMinorUnits,
      resultingFreeCashMinorUnits: resulting,
      horizonMonths: horizon,
      minimumProjectedFreeCashMinorUnits: minimumProjected,
    );
  }
}
