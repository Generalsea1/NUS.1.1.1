import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/domain/financial_alert.dart';

void main() {
  test('critical negative free cash alert takes priority', () {
    final alerts = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 60000,
      actualExpensesMinorUnits: 50000,
      historicalAverageMinorUnits: 20000,
    );

    expect(alerts.first.code, 'negative_free_cash');
    expect(alerts.first.severity, FinancialAlertSeverity.critical);
    expect(alerts.any((alert) => alert.code == 'spending_above_history'), isTrue);
  });

  test('high obligation burden warns when obligations reach half of income', () {
    final alerts = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 50000,
      actualExpensesMinorUnits: 10000,
    );

    expect(alerts.map((alert) => alert.code), contains('high_obligation_burden'));
    expect(alerts.first.severity, FinancialAlertSeverity.warning);
  });

  test('historical spending anomaly is emitted only above twenty percent', () {
    final below = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 10000,
      actualExpensesMinorUnits: 119,
      historicalAverageMinorUnits: 100,
    );
    final above = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 10000,
      actualExpensesMinorUnits: 120,
      historicalAverageMinorUnits: 100,
    );

    expect(below.any((alert) => alert.code == 'spending_above_history'), isFalse);
    expect(above.any((alert) => alert.code == 'spending_above_history'), isTrue);
  });

  test('invalid or missing income produces no alert', () {
    expect(
      FinancialAlertEngine.evaluate(
        monthlyIncomeMinorUnits: 0,
        monthlyObligationsMinorUnits: 100,
        actualExpensesMinorUnits: 100,
      ),
      isEmpty,
    );
  });

  test('results are deterministic for identical facts', () {
    final first = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 20000,
      actualExpensesMinorUnits: 25000,
      historicalAverageMinorUnits: 15000,
    );
    final second = FinancialAlertEngine.evaluate(
      monthlyIncomeMinorUnits: 100000,
      monthlyObligationsMinorUnits: 20000,
      actualExpensesMinorUnits: 25000,
      historicalAverageMinorUnits: 15000,
    );

    expect(
      first.map((alert) => '${alert.code}|${alert.severity}').toList(),
      second.map((alert) => '${alert.code}|${alert.severity}').toList(),
    );
  });
}
