enum FinancialAlertSeverity { info, warning, critical }

class FinancialAlert {
  const FinancialAlert({
    required this.code,
    required this.title,
    required this.message,
    required this.severity,
  });

  final String code;
  final String title;
  final String message;
  final FinancialAlertSeverity severity;
}

/// Converts already-authoritative financial facts into small, explainable
/// alerts. No persistence, prediction, or AI inference happens here.
class FinancialAlertEngine {
  const FinancialAlertEngine._();

  static List<FinancialAlert> evaluate({
    required int monthlyIncomeMinorUnits,
    required int monthlyObligationsMinorUnits,
    required int actualExpensesMinorUnits,
    int? historicalAverageMinorUnits,
  }) {
    if (monthlyIncomeMinorUnits <= 0) return const [];

    final alerts = <FinancialAlert>[];
    final remaining = monthlyIncomeMinorUnits -
        monthlyObligationsMinorUnits -
        actualExpensesMinorUnits;

    if (remaining < 0) {
      alerts.add(
        const FinancialAlert(
          code: 'negative_free_cash',
          title: 'تنبيه: ضغط مالي',
          message: 'الدخل الشهري المسجل لا يغطي الالتزامات والإنفاق الفعلي المسجل هذا الشهر.',
          severity: FinancialAlertSeverity.critical,
        ),
      );
    } else if (monthlyObligationsMinorUnits * 100 >= monthlyIncomeMinorUnits * 50) {
      alerts.add(
        const FinancialAlert(
          code: 'high_obligation_burden',
          title: 'الالتزامات مرتفعة',
          message: 'الالتزامات المسجلة تمثل 50% أو أكثر من الدخل الشهري المسجل.',
          severity: FinancialAlertSeverity.warning,
        ),
      );
    }

    final average = historicalAverageMinorUnits;
    if (average != null && average > 0 && actualExpensesMinorUnits * 100 >= average * 120) {
      alerts.add(
        const FinancialAlert(
          code: 'spending_above_history',
          title: 'الإنفاق أعلى من المعتاد',
          message: 'الإنفاق الفعلي الحالي أعلى من متوسط الفترة المسجلة بأكثر من 20%.',
          severity: FinancialAlertSeverity.warning,
        ),
      );
    }

    alerts.sort((a, b) => _priority(b.severity).compareTo(_priority(a.severity)));
    return List.unmodifiable(alerts);
  }

  static int _priority(FinancialAlertSeverity severity) {
    switch (severity) {
      case FinancialAlertSeverity.critical:
        return 3;
      case FinancialAlertSeverity.warning:
        return 2;
      case FinancialAlertSeverity.info:
        return 1;
    }
  }
}
