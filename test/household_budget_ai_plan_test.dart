import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/domain/household_budget_ai_recommendation.dart';
import 'package:nus/features/expenses/domain/household_budget_plan.dart';

void main() {
  test('AI recommendation supplies missing category amounts and is reflected in the plan', () {
    const ai = HouseholdBudgetAiRecommendation(
      rent: 2500,
      utilities: 700,
      food: 3100,
      transport: 700,
      debt: 500,
      health: 300,
      clothing: 250,
      maintenance: 450,
      familyFun: 300,
      other: 150,
      reserve: 500,
      managerMessage: 'الذكاء الاصطناعي وزّع المتاح حسب الأولويات.',
      recommendation: 'خلي الفسحة والمتفرقات تحت سقف واضح الأسبوع ده.',
    );

    const input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 700,
      transport: 700,
      debt: 500,
      health: 300,
      aiRecommendation: ai,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.isAiPowered, isTrue);
    expect(input.effectiveRent, 2500);
    expect(input.effectiveUtilities, 700);
    expect(input.effectiveFood, 3100);
    expect(input.effectiveTransport, 700);
    expect(input.effectiveDebt, 500);
    expect(input.effectiveHealth, 300);
    expect(input.effectiveClothing, 250);
    expect(input.effectiveMaintenance, 450);
    expect(input.effectiveFamilyFun, 300);
    expect(input.effectiveOther, 150);
    expect(plan.reserve, 500);
    expect(plan.recommendation, contains('الفسحة'));
    expect(plan.management.managerMessage, contains('الذكاء الاصطناعي'));
  });

  test('client-side safety cap prevents an AI response from exceeding available income', () {
    const unsafeAi = HouseholdBudgetAiRecommendation(
      rent: 9000,
      utilities: 8000,
      food: 7000,
      transport: 6000,
      debt: 5000,
      health: 4000,
      clothing: 3000,
      maintenance: 2000,
      familyFun: 1500,
      other: 1000,
      reserve: 5000,
      managerMessage: 'unsafe test response',
      recommendation: 'unsafe test response',
    );

    const input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 500,
      transport: 500,
      debt: 500,
      health: 200,
      aiRecommendation: unsafeAi,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.isAiPowered, isTrue);
    expect(plan.plannedTotal, lessThanOrEqualTo(10000));
    expect(plan.status, isNot(BudgetStatus.overBudget));
    expect(plan.weeklyAllowance, greaterThanOrEqualTo(0));
  });
}
