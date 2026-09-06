import 'household_budget_ai_recommendation.dart';
import 'household_budget_management.dart';

/// Domain model for the "Household Expense Manager" experience.
///
/// A missing category is deliberately left unplanned until the user supplies
/// a value or the connected AI provider creates an explicit recommendation.
class HouseholdBudgetInput {
  const HouseholdBudgetInput({
    required this.monthlyIncome,
    this.rent = 0,
    this.utilities = 0,
    this.food = 0,
    this.transport = 0,
    this.debt = 0,
    this.health = 0,
    this.clothing = 0,
    this.maintenance = 0,
    this.familyFun = 0,
    this.other = 0,
    this.savingsTarget = 0,
    this.aiRecommendation,
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
  final HouseholdBudgetAiRecommendation? aiRecommendation;

  int get knownMandatoryTotal => rent + utilities + transport + debt + health;
  int get knownFlexibleTotal => food + clothing + maintenance + familyFun + other;
  int get mandatoryTotal => knownMandatoryTotal + effectiveFood;
  int get flexibleTotal => effectiveClothing + effectiveMaintenance + effectiveFamilyFun + effectiveOther;
  int get plannedTotal => mandatoryTotal + flexibleTotal + effectiveReserve;

  /// Income is not spendable while any AI-managed category is still missing.
  /// This prevents the UI from presenting the unallocated remainder as if it
  /// were a safe amount available for discretionary spending.
  int get unallocated => hasMissingCategories && aiRecommendation == null
      ? 0
      : monthlyIncome - plannedTotal;

  bool get isOverBudget => knownMandatoryTotal + knownFlexibleTotal + savingsTarget > monthlyIncome;

  bool get hasMissingCategories =>
      food == 0 || clothing == 0 || maintenance == 0 || familyFun == 0 || other == 0;

  bool get hasReadyPlan => monthlyIncome > 0 && (!hasMissingCategories || aiRecommendation != null);

  int get effectiveFood => _effective(food, aiRecommendation?.food);
  int get effectiveClothing => _effective(clothing, aiRecommendation?.clothing);
  int get effectiveMaintenance => _effective(maintenance, aiRecommendation?.maintenance);
  int get effectiveFamilyFun => _effective(familyFun, aiRecommendation?.familyFun);
  int get effectiveOther => _effective(other, aiRecommendation?.other);

  int get effectiveReserve {
    if (savingsTarget > 0) return savingsTarget;
    return aiRecommendation?.reserve.clamp(0, _availableBeforeAiReserve) ?? 0;
  }

  int get _availableBeforeAiReserve =>
      (monthlyIncome - knownMandatoryTotal - knownFlexibleTotal - _aiMissingCategoryTotal)
          .clamp(0, 0x7fffffffffffffff);

  int get _aiMissingCategoryTotal => [
        if (food == 0) aiRecommendation?.food ?? 0,
        if (clothing == 0) aiRecommendation?.clothing ?? 0,
        if (maintenance == 0) aiRecommendation?.maintenance ?? 0,
        if (familyFun == 0) aiRecommendation?.familyFun ?? 0,
        if (other == 0) aiRecommendation?.other ?? 0,
      ].fold<int>(0, (sum, value) => sum + value.clamp(0, 0x7fffffffffffffff));

  int _effective(int known, int? ai) {
    if (known > 0) return known;
    return (ai ?? 0).clamp(0, 0x7fffffffffffffff);
  }
}

class HouseholdBudgetPlan {
  const HouseholdBudgetPlan({
    required this.input,
    required this.reserve,
    required this.weeklyAllowance,
    required this.recommendation,
    required this.status,
    required this.management,
  });

  final HouseholdBudgetInput input;
  final int reserve;
  final int weeklyAllowance;
  final String recommendation;
  final BudgetStatus status;
  final HouseholdBudgetManagement management;

  int get plannedTotal => input.plannedTotal;
  int get remaining => input.unallocated;
  bool get isAiPowered => input.aiRecommendation != null;
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
      management: _management(input, 0, 0),
    );
  }

  final reserve = input.effectiveReserve;
  final remaining = input.unallocated;
  final weeklyAllowance = remaining > 0 && !input.hasMissingCategories
      ? (remaining / 4.33).round()
      : 0;

  if (input.isOverBudget || remaining < 0) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: 0,
      recommendation: input.aiRecommendation?.recommendation.isNotEmpty == true
          ? input.aiRecommendation!.recommendation
          : 'الخطة أعلى من الدخل. ابدأ بالالتزامات الأساسية، ثم خفّض البنود المرنة والمشتريات غير الضرورية قبل المساس بالأساسيات.',
      status: BudgetStatus.overBudget,
      management: _management(input, reserve, 0),
    );
  }

  final status = reserve / input.monthlyIncome < 0.03 ? BudgetStatus.tight : BudgetStatus.healthy;
  final recommendation = input.aiRecommendation?.recommendation.isNotEmpty == true
      ? input.aiRecommendation!.recommendation
      : input.hasMissingCategories
          ? 'لسه في بنود مصروفات ناقصة. اكتب أرقامك الفعلية أو شغّل مدير المنزل بالذكاء الاصطناعي عشان يوزّعها على الدخل بدل ما البرنامج يفترض أرقام من عنده.'
          : 'الخطة مبنية على الأرقام التي أدخلتها. المبلغ المتبقي يظل هامش حركة ولا يُعتبر إذنًا بإنفاقه كله.';

  return HouseholdBudgetPlan(
    input: input,
    reserve: reserve,
    weeklyAllowance: weeklyAllowance,
    recommendation: recommendation,
    status: status,
    management: _management(input, reserve, weeklyAllowance),
  );
}

HouseholdBudgetManagement _management(HouseholdBudgetInput input, int reserve, int weeklyAllowance) {
  final aiMessage = input.aiRecommendation?.managerMessage;
  return buildHouseholdBudgetManagement(
    rent: input.rent,
    utilities: input.utilities,
    food: input.effectiveFood,
    transport: input.transport,
    debt: input.debt,
    health: input.health,
    clothing: input.effectiveClothing,
    maintenance: input.effectiveMaintenance,
    familyFun: input.effectiveFamilyFun,
    other: input.effectiveOther,
    reserve: reserve,
    weeklyRoom: weeklyAllowance,
    knownFood: input.food,
    knownClothing: input.clothing,
    knownMaintenance: input.maintenance,
    knownFamilyFun: input.familyFun,
    knownOther: input.other,
    managerMessageOverride: aiMessage?.isNotEmpty == true ? aiMessage : null,
  );
}