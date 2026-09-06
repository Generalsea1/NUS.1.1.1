import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/domain/household_budget_plan.dart';

void main() {
  test('keeps a balanced household plan inside the monthly income', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 700,
      food: 2200,
      transport: 700,
      debt: 500,
      health: 300,
      clothing: 300,
      maintenance: 200,
      familyFun: 400,
      other: 200,
      savingsTarget: 1000,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.status, BudgetStatus.healthy);
    expect(plan.plannedTotal, 9000);
    expect(plan.remaining, 1000);
    expect(plan.weeklyAllowance, 231);
    expect(plan.reserve, 1000);
  });

  test('marks an over-budget household plan and stops weekly allowance', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 4000,
      utilities: 1000,
      food: 3000,
      transport: 1000,
      debt: 1000,
      health: 500,
      clothing: 500,
      maintenance: 500,
      familyFun: 500,
      other: 500,
      savingsTarget: 100,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.status, BudgetStatus.overBudget);
    expect(plan.input.isOverBudget, isTrue);
    expect(plan.weeklyAllowance, 0);
    expect(plan.recommendation, contains('الخطة أعلى من الدخل'));
  });

  test('does not invent an emergency reserve without a target or AI recommendation', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 500,
      food: 1500,
      transport: 500,
      debt: 500,
      health: 200,
      clothing: 200,
      maintenance: 100,
      familyFun: 200,
      other: 100,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.status, BudgetStatus.tight);
    expect(plan.reserve, 0);
    expect(plan.plannedTotal, 6300);
    expect(plan.remaining, 3700);
    expect(plan.weeklyAllowance, 855);
  });

  test('does not auto-allocate missing household categories', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 700,
      transport: 700,
      debt: 500,
      health: 300,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.status, BudgetStatus.tight);
    expect(input.effectiveFood, 0);
    expect(input.effectiveClothing, 0);
    expect(input.effectiveMaintenance, 0);
    expect(input.effectiveFamilyFun, 0);
    expect(input.effectiveOther, 0);
    expect(plan.reserve, 0);
    expect(plan.plannedTotal, 4700);
    expect(plan.remaining, 5300);
    expect(plan.weeklyAllowance, 0);
    expect(plan.recommendation, contains('لسه في بنود مصروفات ناقصة'));
  });

  test('manual category values remain authoritative while missing categories stay unplanned', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 700,
      food: 2000,
      transport: 700,
      debt: 500,
      health: 300,
      clothing: 300,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(input.effectiveFood, 2000);
    expect(input.effectiveClothing, 300);
    expect(input.effectiveMaintenance, 0);
    expect(input.effectiveFamilyFun, 0);
    expect(input.effectiveOther, 0);
    expect(plan.status, BudgetStatus.tight);
    expect(plan.weeklyAllowance, 0);
  });
}
