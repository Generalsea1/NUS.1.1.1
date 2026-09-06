import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/domain/household_budget_actual_comparison.dart';

void main() {
  test('reports remaining room when actual spending is below plan', () {
    const comparison = HouseholdBudgetActualComparison(
      plannedAmount: 8000,
      actualAmount: 6250,
    );

    expect(comparison.variance, 1750);
    expect(comparison.isOverPlan, isFalse);
    expect(comparison.progressPercent, closeTo(78.125, 0.001));
    expect(comparison.managerMessage, contains('داخل الخطة'));
  });

  test('reports over-plan spending and negative variance', () {
    const comparison = HouseholdBudgetActualComparison(
      plannedAmount: 8000,
      actualAmount: 9250,
    );

    expect(comparison.variance, -1250);
    expect(comparison.isOverPlan, isTrue);
    expect(comparison.isOnOrUnderPlan, isFalse);
    expect(comparison.progressPercent, closeTo(115.625, 0.001));
    expect(comparison.managerMessage, contains('عدى الخطة'));
  });

  test('handles a plan with no amount safely', () {
    const empty = HouseholdBudgetActualComparison(
      plannedAmount: 0,
      actualAmount: 0,
    );
    const unplanned = HouseholdBudgetActualComparison(
      plannedAmount: 0,
      actualAmount: 100,
    );

    expect(empty.progressPercent, 0);
    expect(empty.isOverPlan, isFalse);
    expect(unplanned.progressPercent, 100);
    expect(unplanned.isOverPlan, isTrue);
    expect(unplanned.managerMessage, contains('من غير ميزانية'));
  });
}
