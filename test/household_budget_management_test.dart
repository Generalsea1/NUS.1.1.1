import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/expenses/domain/household_budget_management.dart';
import 'package:nus/features/expenses/domain/household_budget_plan.dart';

void main() {
  test('management protects essentials and reserve before flexible cuts', () {
    final input = HouseholdBudgetInput(
      monthlyIncome: 10000,
      rent: 2500,
      utilities: 700,
      transport: 700,
      debt: 500,
      health: 300,
    );

    final plan = buildHouseholdBudgetPlan(input);

    expect(plan.management.lines, hasLength(11));
    expect(plan.management.protectedAmount, 4200);
    expect(plan.management.flexibleRoom, 0);
    expect(plan.management.weeklyRoom, 0);
    expect(plan.management.cutOrder, <String>[
      'other',
      'familyFun',
      'clothing',
      'maintenance',
      'food',
    ]);
  });

  test('management marks automatically allocated categories', () {
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
    final byKey = <String, HouseholdBudgetLine>{
      for (final line in plan.management.lines) line.key: line,
    };

    expect(byKey['food']!.autoAllocated, isFalse);
    expect(byKey['clothing']!.autoAllocated, isFalse);
    expect(byKey['maintenance']!.autoAllocated, isTrue);
    expect(byKey['familyFun']!.autoAllocated, isTrue);
    expect(byKey['other']!.autoAllocated, isTrue);
    expect(byKey['reserve']!.priority, HouseholdBudgetPriority.reserve);
  });

  test('weekly caps follow the same 4.33-week planning basis', () {
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
    final foodLine = plan.management.lines.firstWhere((line) => line.key == 'food');

    expect(foodLine.weeklyCap, 462);
    expect(foodLine.priority, HouseholdBudgetPriority.essential);
  });
}
