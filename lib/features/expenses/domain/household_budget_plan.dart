/// Domain model for the "Household Expense Manager" experience.
///
/// The planner is intentionally deterministic and provider-agnostic. It uses
/// user-entered values when available and can provisionally allocate missing
/// categories from the remaining household envelope. A future AI advisor can
/// consume the same contract without changing the UI boundary.
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

  int get knownMandatoryTotal => rent + utilities + transport + debt + health;
  int get knownFlexibleTotal => food + clothing + maintenance + familyFun + other;
  int get mandatoryTotal => knownMandatoryTotal + effectiveFood;
  int get flexibleTotal =>
      effectiveClothing + effectiveMaintenance + effectiveFamilyFun + effectiveOther;
  int get plannedTotal => mandatoryTotal + flexibleTotal + effectiveReserve;
  int get unallocated => monthlyIncome - plannedTotal;
  bool get isOverBudget =>
      knownMandatoryTotal + knownFlexibleTotal + savingsTarget > monthlyIncome;

  int get effectiveFood => food > 0 ? food : _autoFood;
  int get effectiveClothing => clothing > 0 ? clothing : _autoClothing;
  int get effectiveMaintenance =>
      maintenance > 0 ? maintenance : _autoMaintenance;
  int get effectiveFamilyFun => familyFun > 0 ? familyFun : _autoFamilyFun;
  int get effectiveOther => other > 0 ? other : _autoOther;

  int get effectiveReserve {
    if (savingsTarget > 0) return savingsTarget;
    if (monthlyIncome <= 0) return 0;
    final base = monthlyIncome - knownMandatoryTotal - knownFlexibleTotal;
    return base > 0 ? (base * 0.10).round() : 0;
  }

  int get _autoEnvelope {
    final base = monthlyIncome - knownMandatoryTotal - knownFlexibleTotal;
    final reserve = savingsTarget > 0
        ? savingsTarget
        : (base > 0 ? (base * 0.10).round() : 0);
    return base - reserve;
  }

  // Deterministic baseline weights. They are fallback envelopes, not claims
  // that every family should spend the same percentages. Twenty percent of
  // the post-reserve envelope remains deliberately unallocated as a buffer.
  int get _autoFood =>
      food > 0 ? 0 : _shareForMissing(_autoEnvelope, 0.50);
  int get _autoClothing =>
      clothing > 0 ? 0 : _shareForMissing(_autoEnvelope, 0.08);
  int get _autoMaintenance =>
      maintenance > 0 ? 0 : _shareForMissing(_autoEnvelope, 0.08);
  int get _autoFamilyFun =>
      familyFun > 0 ? 0 : _shareForMissing(_autoEnvelope, 0.08);
  int get _autoOther =>
      other > 0 ? 0 : _shareForMissing(_autoEnvelope, 0.06);

  int _shareForMissing(int envelope, double weight) {
    if (envelope <= 0 || weight <= 0) return 0;
    return (envelope * weight).round();
  }
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
      recommendation:
          'ابدأ بتسجيل الدخل الشهري أولاً حتى يقدر مدير المنزل يوزّع المصروفات بشكل صحيح.',
      status: BudgetStatus.overBudget,
    );
  }

  if (input.isOverBudget) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: input.savingsTarget,
      weeklyAllowance: 0,
      recommendation:
          'الخطة أعلى من الدخل. ابدأ بالالتزامات الأساسية، ثم خفّض البنود المرنة والمشتريات غير الضرورية قبل المساس بالأساسيات.',
      status: BudgetStatus.overBudget,
    );
  }

  final remaining = input.remaining;
  final reserve = input.effectiveReserve;
  final weeklyAllowance = remaining > 0 ? (remaining / 4.33).round() : 0;
  final hasMissingPlanningInputs = input.food == 0 ||
      input.clothing == 0 ||
      input.maintenance == 0 ||
      input.familyFun == 0 ||
      input.other == 0;

  if (remaining < 0) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: 0,
      recommendation:
          'الخطة أعلى من الدخل بعد إضافة الاحتياطي. خفّض المصروفات المرنة أو هدف الادخار قبل اعتماد الشهر.',
      status: BudgetStatus.overBudget,
    );
  }

  final reserveRatio = input.monthlyIncome == 0 ? 0 : reserve / input.monthlyIncome;
  if (reserveRatio < 0.05) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: weeklyAllowance,
      recommendation: _balancedRecommendation(
        input,
        reserve,
        hasMissingPlanningInputs,
      ),
      status: BudgetStatus.tight,
    );
  }

  return HouseholdBudgetPlan(
    input: input,
    reserve: reserve,
    weeklyAllowance: weeklyAllowance,
    recommendation: _balancedRecommendation(
      input,
      reserve,
      hasMissingPlanningInputs,
    ),
    status: BudgetStatus.healthy,
  );
}

String _balancedRecommendation(
  HouseholdBudgetInput input,
  int reserve,
  bool hasMissingPlanningInputs,
) {
  final prefix = hasMissingPlanningInputs
      ? 'مدير المنزل عمل لك توزيعًا مبدئيًا للبنود التي لم تدخل لها رقمًا. '
      : 'الخطة مبنية على الأرقام التي أدخلتها. ';
  return '$prefix'
      'السقف المقترح: أغذية ${input.effectiveFood} جنيه، ملابس ${input.effectiveClothing}، '
      'صيانة ${input.effectiveMaintenance}، فسحة ${input.effectiveFamilyFun}، '
      'ومتفرقات ${input.effectiveOther}. احتياطي الشهر $reserve جنيه. '
      'المبلغ المتبقي بعد الخطة يظل هامش حركة للأسبوع، ولا يُعتبر إذنًا بإنفاقه كله.';
}
