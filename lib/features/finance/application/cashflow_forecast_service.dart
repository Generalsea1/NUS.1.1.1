import '../../expenses/domain/currency_registry.dart';
import '../domain/cashflow_forecast.dart';
import 'financial_engine.dart';

/// Conservative, explainable cash-flow projection built on the same financial
/// engine used by the dashboard. It does not predict income changes or future
/// exceptional spending; it projects committed obligations and a historical
/// discretionary-spending baseline separately.
class CashflowForecastService {
  const CashflowForecastService({required FinancialEngine financialEngine})
      : _financialEngine = financialEngine;

  final FinancialEngine _financialEngine;

  Future<CashflowForecast> forecast({
    required String userId,
    required int year,
    required int month,
    required String currencyCode,
    int historyMonths = 3,
    int forecastMonths = 3,
  }) async {
    if (historyMonths < 1 || historyMonths > 12) {
      throw ArgumentError.value(
        historyMonths,
        'historyMonths',
        'History must contain between 1 and 12 months.',
      );
    }
    if (forecastMonths < 1 || forecastMonths > 12) {
      throw ArgumentError.value(
        forecastMonths,
        'forecastMonths',
        'Forecast must contain between 1 and 12 months.',
      );
    }

    final currency = currencyCode.trim().toUpperCase();
    final metadata = CurrencyRegistry.get(currency);
    final target = _Period(year, month);
    final historicalSnapshots = <FinancialSnapshot>[];

    for (var offset = historyMonths; offset >= 1; offset--) {
      final period = _shift(target, -offset);
      historicalSnapshots.add(
        await _financialEngine.calculate(
          userId: userId,
          year: period.year,
          month: period.month,
          currencyCode: currency,
        ),
      );
    }

    final targetSnapshot = await _financialEngine.calculate(
      userId: userId,
      year: target.year,
      month: target.month,
      currencyCode: currency,
    );

    final discretionarySamples = historicalSnapshots
        .where((snapshot) => snapshot.actualExpensesMinorUnits > 0)
        .map((snapshot) =>
            (snapshot.actualExpensesMinorUnits -
                    snapshot.monthlyObligationsMinorUnits)
                .clamp(0, 0x7fffffffffffffff)
                .toInt())
        .toList(growable: false);

    final averageDiscretionary = discretionarySamples.isEmpty
        ? 0
        : discretionarySamples.fold<int>(0, (sum, value) => sum + value) ~/
            discretionarySamples.length;

    final incomeMinor = targetSnapshot.monthlyIncomeMinorUnits;
    final obligationMinor = targetSnapshot.monthlyObligationsMinorUnits;
    final projectedFreeCash =
        incomeMinor - obligationMinor - averageDiscretionary;

    final points = <CashflowForecastPoint>[];
    for (var offset = 1; offset <= forecastMonths; offset++) {
      final period = _shift(target, offset);
      points.add(
        CashflowForecastPoint(
          year: period.year,
          month: period.month,
          incomeMinorUnits: incomeMinor,
          obligationsMinorUnits: obligationMinor,
          discretionaryExpenseEstimateMinorUnits: averageDiscretionary,
          projectedFreeCashMinorUnits: projectedFreeCash,
        ),
      );
    }

    return CashflowForecast(
      currencyCode: metadata.code,
      historyMonthsUsed: discretionarySamples.length,
      averageDiscretionaryExpenseMinorUnits: averageDiscretionary,
      points: List.unmodifiable(points),
    );
  }

  _Period _shift(_Period base, int delta) {
    final zeroBased = base.year * 12 + (base.month - 1) + delta;
    final year = zeroBased ~/ 12;
    final month = (zeroBased % 12) + 1;
    return _Period(year, month);
  }
}

class _Period {
  const _Period(this.year, this.month);

  final int year;
  final int month;
}
