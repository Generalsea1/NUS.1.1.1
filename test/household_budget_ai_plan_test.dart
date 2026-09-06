import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/domain/household_budget_ai_recommendation.dart';
import 'package:nus/features/expenses/domain/household_budget_plan.dart';

void main() {
  test('AI recommendation supplies missing category amounts and is reflected in the plan', () {
    const ai = HouseholdBudgetAiRecommendation(
      food: 3100,
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
    expect(input.effectiveFood, 3100);
    expect(input.effectiveClothing, 250);
    expect(input.effectiveMaintenance, 450);
    expect(input.effectiveFamilyFun, 300);
    expect(input.effectiveOther, 150);
    expect(plan.reserve, 500);
    expect(plan.recommendation, contains('الفسحة'));
    expect(plan.management.managerMessage, contains('الذكاء الاصطناعي'));
  });
}
