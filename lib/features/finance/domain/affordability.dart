enum AffordabilityStatus { affordable, pressure, notAffordable }

class AffordabilityAssessment {
  const AffordabilityAssessment({
    required this.status,
    required this.currencyCode,
    required this.proposedMinorUnits,
    required this.monthlyIncomeMinorUnits,
    required this.monthlyObligationsMinorUnits,
    required this.existingActualExpensesMinorUnits,
    required this.resultingFreeCashMinorUnits,
    required this.horizonMonths,
    required this.minimumProjectedFreeCashMinorUnits,
  });

  final AffordabilityStatus status;
  final String currencyCode;
  final int proposedMinorUnits;
  final int monthlyIncomeMinorUnits;
  final int monthlyObligationsMinorUnits;
  final int existingActualExpensesMinorUnits;
  final int resultingFreeCashMinorUnits;

  /// The number of months used for a recurring stress scenario.
  /// One-time proposals always use one month.
  final int horizonMonths;

  /// Minimum free cash across the deterministic recurring scenario.
  /// This is not a forecast: it assumes the supplied monthly facts repeat.
  final int minimumProjectedFreeCashMinorUnits;

  bool get isAffordable => status == AffordabilityStatus.affordable;
  bool get isPressure => status == AffordabilityStatus.pressure;
}
