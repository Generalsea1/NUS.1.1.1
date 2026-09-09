class CashflowForecastPoint {
  const CashflowForecastPoint({
    required this.year,
    required this.month,
    required this.incomeMinorUnits,
    required this.obligationsMinorUnits,
    required this.discretionaryExpenseEstimateMinorUnits,
    required this.projectedFreeCashMinorUnits,
  });

  final int year;
  final int month;
  final int incomeMinorUnits;
  final int obligationsMinorUnits;
  final int discretionaryExpenseEstimateMinorUnits;
  final int projectedFreeCashMinorUnits;

  String get periodLabel => '${month.toString().padLeft(2, '0')}/$year';
}

class CashflowForecast {
  const CashflowForecast({
    required this.currencyCode,
    required this.historyMonthsUsed,
    required this.averageDiscretionaryExpenseMinorUnits,
    required this.points,
  });

  final String currencyCode;
  final int historyMonthsUsed;
  final int averageDiscretionaryExpenseMinorUnits;
  final List<CashflowForecastPoint> points;

  bool get isPositive =>
      points.isNotEmpty && points.every((point) => point.projectedFreeCashMinorUnits >= 0);
}
