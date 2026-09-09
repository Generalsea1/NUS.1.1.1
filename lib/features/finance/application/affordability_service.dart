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
  }) async {
    if (proposedMinorUnits <= 0) {
      throw ArgumentError.value(
        proposedMinorUnits,
        'proposedMinorUnits',
        'The proposed amount must be greater than zero.',
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

    // Both one-time and recurring proposals are treated as a first-pass
    // monthly affordability question. Recurrence is retained on the input so
    // the UX can distinguish the user's intent, while the engine stays honest
    // and does not pretend to model future months differently yet.
    final resulting = availableBeforeProposal - proposedMinorUnits;

    final status = resulting < 0
        ? AffordabilityStatus.notAffordable
        : resulting < incomeMinor ~/ 10
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
    );
  }
}
