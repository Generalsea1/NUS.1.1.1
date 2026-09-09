import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/domain/financial_alert.dart';

void main() {
  test('negative cash alert is first and explains the authoritative facts', () {
    final alerts = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 60000,
      actualExpensesMinorUnits: 50000,
      historicalAverageMinorUnits: 20000,
    );

    expect(alerts, isNotEmpty);
    expect(alerts.first.code, 'negative_free_cash');
    expect(alerts.first.title, 'تنبيه: ضغط مالي');
    expect(alerts.first.message, contains('الدخل الشهري المسجل'));
    expect(alerts.first.severity, FinancialAlertSeverity.critical);
  });

  test('no alert is invented when income is unavailable', () {
    final alerts = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 0,
      monthlyObligationsMinorUnits: 90000,
      actualExpensesMinorUnits: 90000,
      historicalAverageMinorUnits: 10000,
    );

    expect(alerts, isEmpty);
  });
}
