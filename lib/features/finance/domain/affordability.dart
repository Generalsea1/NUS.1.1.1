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
  });

  final AffordabilityStatus status;
  final String currencyCode;
  final int proposedMinorUnits;
  final int monthlyIncomeMinorUnits;
  final int monthlyObligationsMinorUnits;
  final int existingActualExpensesMinorUnits;
  final int resultingFreeCashMinorUnits;

  bool get isAffordable => status == AffordabilityStatus.affordable;
  bool get isPressure => status == AffordabilityStatus.pressure;
}
