/// Domain model for the "Household Expense Manager" experience.
///
/// This is intentionally provider-agnostic: the local planner is a safe
/// baseline today, while a future AI advisor can consume the same inputs and
/// return richer recommendations without changing the UI contract.
class HouseholdBudgetInput {
  const HouseholdBudgetInput({
    required this.monthlyIncome,
    required this.rent,
    required this.utilities,
    required this.food,
    required this.transport,
    required this.debt,
    required this.health,
    required this.clothing,
    required this.maintenance,
    required this.familyFun,
    required this.other,
    this.savingsTarget = 0,
  });

  final int monthlyIncome;
  final int rent;
  final int utilities;
  final int food;
  final int transport;
  final int debt;
  final int health;
  final int clothing;
  final int maintenance;
  final int familyFun;
  final int other;
  final int savingsTarget;

  int get mandatoryTotal => rent + utilities + food + transport + debt + health;
  int get flexibleTotal => clothing + maintenance + familyFun + other;
  int get plannedTotal => mandatoryTotal + flexibleTotal + savingsTarget;
  int get unallocated => monthlyIncome - plannedTotal;
  bool get isOverBudget => plannedTotal > monthlyIncome;
}

class HouseholdBudgetPlan {
  const HouseholdBudgetPlan({
    required this.input,
    required this.reserve,
    required this.weeklyAllowance,
    required this.recommendation,
    required this.status,
  });

  final HouseholdBudgetInput input;
  final int reserve;
  final int weeklyAllowance;
  final String recommendation;
  final BudgetStatus status;

  int get plannedTotal => input.plannedTotal;
  int get remaining => input.monthlyIncome - plannedTotal;
}

enum BudgetStatus { healthy, tight, overBudget }

HouseholdBudgetPlan buildHouseholdBudgetPlan(HouseholdBudgetInput input) {
  if (input.monthlyIncome <= 0) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: 0,
      weeklyAllowance: 0,
      recommendation: 'ابدأ بتسجيل الدخل الشهري أولاً حتى يقدر مدير المنزل يوزّع المصروفات بشكل صحيح.',
      status: BudgetStatus.overBudget,
    );
  }

  final remaining = input.unallocated;
  final reserve = input.savingsTarget > 0
      ? input.savingsTarget
      : (remaining > 0 ? (remaining * 0.10).round() : 0);
  final weeklyAllowance = remaining > 0 ? (remaining / 4.33).round() : 0;

  if (input.isOverBudget) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: 0,
      recommendation: 'الخطة أعلى من الدخل. ابدأ بالالتزامات الأساسية، ثم خفّض بند الرفاهية والمشتريات غير الضرورية قبل المساس بالأساسيات.',
      status: BudgetStatus.overBudget,
    );
  }

  final reserveRatio = reserve / input.monthlyIncome;
  if (reserveRatio < 0.05) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: weeklyAllowance,
      recommendation: 'ميزانيتك قابلة للإدارة، لكن هامش الأمان ضعيف. حاول تكوين احتياطي صغير للطوارئ قبل زيادة المصروفات المرنة.',
      status: BudgetStatus.tight,
    );
  }

  return HouseholdBudgetPlan(
    input: input,
    reserve: reserve,
    weeklyAllowance: weeklyAllowance,
    recommendation: 'الدخل متوازن مع الخطة. حافظ على الالتزامات الأساسية، واقسم المبلغ المتاح أسبوعيًا حتى لا يستهلك الشهر في بدايته.',
    status: BudgetStatus.healthy,
  );
}
