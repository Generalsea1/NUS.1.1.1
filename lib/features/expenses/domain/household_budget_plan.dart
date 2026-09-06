import 'household_budget_ai_recommendation.dart';
import 'household_budget_management.dart';

/// Inputs collected by the household manager.
///
/// A positive value typed by the user is considered provided even when an
/// older caller does not yet send `providedFields`. Empty fields remain
/// unknown and may be planned by AI.
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
    this.providedFields = const <String>{},
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
  final Set<String> providedFields;
  final HouseholdBudgetAiRecommendation? aiRecommendation;

  static const managedCategories = <String>[
    'rent',
    'utilities',
    'food',
    'transport',
    'debt',
    'health',
    'clothing',
    'maintenance',
    'familyFun',
    'other',
  ];

  int valueFor(String key) {
    switch (key) {
      case 'rent': return rent;
      case 'utilities': return utilities;
      case 'food': return food;
      case 'transport': return transport;
      case 'debt': return debt;
      case 'health': return health;
      case 'clothing': return clothing;
      case 'maintenance': return maintenance;
      case 'familyFun': return familyFun;
      case 'other': return other;
      case 'savingsTarget': return savingsTarget;
      default: return 0;
    }
  }

  bool isProvided(String key) =>
      providedFields.contains(key) || valueFor(key) > 0;

  int get knownMandatoryTotal =>
      (isProvided('rent') ? rent : 0) +
      (isProvided('utilities') ? utilities : 0) +
      (isProvided('transport') ? transport : 0) +
      (isProvided('debt') ? debt : 0) +
      (isProvided('health') ? health : 0);

  int get knownFlexibleTotal =>
      (isProvided('food') ? food : 0) +
      (isProvided('clothing') ? clothing : 0) +
      (isProvided('maintenance') ? maintenance : 0) +
      (isProvided('familyFun') ? familyFun : 0) +
      (isProvided('other') ? other : 0);

  int get mandatoryTotal => effectiveRent + effectiveUtilities + effectiveFood + effectiveTransport + effectiveDebt + effectiveHealth;
  int get flexibleTotal => effectiveClothing + effectiveMaintenance + effectiveFamilyFun + effectiveOther;
  int get plannedTotal => mandatoryTotal + flexibleTotal + effectiveReserve;

  int get unallocated => hasMissingCategories && aiRecommendation == null
      ? 0
      : monthlyIncome - plannedTotal;

  bool get isOverBudget => monthlyIncome > 0 && plannedTotal > monthlyIncome;

  bool get hasMissingCategories => managedCategories.any((key) => !isProvided(key));

  bool get hasReadyPlan => monthlyIncome > 0 && (!hasMissingCategories || aiRecommendation != null);

  int get effectiveRent => _effective('rent', rent, aiRecommendation?.rent);
  int get effectiveUtilities => _effective('utilities', utilities, aiRecommendation?.utilities);
  int get effectiveFood => _effective('food', food, aiRecommendation?.food);
  int get effectiveTransport => _effective('transport', transport, aiRecommendation?.transport);
  int get effectiveDebt => _effective('debt', debt, aiRecommendation?.debt);
  int get effectiveHealth => _effective('health', health, aiRecommendation?.health);
  int get effectiveClothing => _effective('clothing', clothing, aiRecommendation?.clothing);
  int get effectiveMaintenance => _effective('maintenance', maintenance, aiRecommendation?.maintenance);
  int get effectiveFamilyFun => _effective('familyFun', familyFun, aiRecommendation?.familyFun);
  int get effectiveOther => _effective('other', other, aiRecommendation?.other);

  int get effectiveReserve {
    if (savingsTarget > 0) return savingsTarget;
    return aiRecommendation?.reserve.clamp(0, _availableBeforeAiReserve) ?? 0;
  }

  int get _availableBeforeAiReserve =>
      (monthlyIncome - knownMandatoryTotal - knownFlexibleTotal - _aiMissingCategoryTotal)
          .clamp(0, 0x7fffffffffffffff);

  int get _aiMissingCategoryTotal => [
        if (!isProvided('rent')) aiRecommendation?.rent ?? 0,
        if (!isProvided('utilities')) aiRecommendation?.utilities ?? 0,
        if (!isProvided('food')) aiRecommendation?.food ?? 0,
        if (!isProvided('transport')) aiRecommendation?.transport ?? 0,
        if (!isProvided('debt')) aiRecommendation?.debt ?? 0,
        if (!isProvided('health')) aiRecommendation?.health ?? 0,
        if (!isProvided('clothing')) aiRecommendation?.clothing ?? 0,
        if (!isProvided('maintenance')) aiRecommendation?.maintenance ?? 0,
        if (!isProvided('familyFun')) aiRecommendation?.familyFun ?? 0,
        if (!isProvided('other')) aiRecommendation?.other ?? 0,
      ].fold<int>(0, (sum, value) => sum + value.clamp(0, 0x7fffffffffffffff));

  int _effective(String key, int known, int? ai) {
    if (isProvided(key)) return known;
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

enum BudgetStatus { healthy, tight, overBudget, incomplete }

HouseholdBudgetPlan buildHouseholdBudgetPlan(HouseholdBudgetInput rawInput) {
  final input = _sanitizeAiRecommendation(rawInput);

  if (input.monthlyIncome <= 0) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: 0,
      weeklyAllowance: 0,
      recommendation: 'ابدأ بالدخل الشهري أولًا عشان مدير المنزل يقدر يبني خطة على رقم حقيقي.',
      status: BudgetStatus.incomplete,
      management: _management(input, 0, 0),
    );
  }

  if (!input.hasReadyPlan) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: 0,
      weeklyAllowance: 0,
      recommendation: 'لسه في بنود غير معروفة. شغّل مدير المنزل بالذكاء الاصطناعي عشان يضع لها خطة، أو أدخل أرقامك الفعلية.',
      status: BudgetStatus.incomplete,
      management: _management(input, 0, 0),
    );
  }

  final reserve = input.effectiveReserve;
  final remaining = input.unallocated;
  final weeklyAllowance = remaining > 0 ? (remaining / 4.33).round() : 0;

  if (input.isOverBudget || remaining < 0) {
    return HouseholdBudgetPlan(
      input: input,
      reserve: reserve,
      weeklyAllowance: 0,
      recommendation: input.aiRecommendation?.recommendation.isNotEmpty == true
          ? input.aiRecommendation!.recommendation
          : 'الخطة أعلى من الدخل. ابدأ بالالتزامات الأساسية، ثم خفّض البنود المرنة قبل المساس بالاحتياجات الضرورية.',
      status: BudgetStatus.overBudget,
      management: _management(input, reserve, 0),
    );
  }

  final status = reserve / input.monthlyIncome < 0.03 ? BudgetStatus.tight : BudgetStatus.healthy;
  final recommendation = input.aiRecommendation?.recommendation.isNotEmpty == true
      ? input.aiRecommendation!.recommendation
      : 'الخطة محسوبة من الأرقام التي أدخلتها. المتبقي ليس دعوة لإنفاقه كله؛ حافظ على هامش أمان.';

  return HouseholdBudgetPlan(
    input: input,
    reserve: reserve,
    weeklyAllowance: weeklyAllowance,
    recommendation: recommendation,
    status: status,
    management: _management(input, reserve, weeklyAllowance),
  );
}

HouseholdBudgetInput _sanitizeAiRecommendation(HouseholdBudgetInput input) {
  final ai = input.aiRecommendation;
  if (ai == null) return input;

  final missing = <String>[
    if (!input.isProvided('rent')) 'rent',
    if (!input.isProvided('utilities')) 'utilities',
    if (!input.isProvided('food')) 'food',
    if (!input.isProvided('transport')) 'transport',
    if (!input.isProvided('debt')) 'debt',
    if (!input.isProvided('health')) 'health',
    if (!input.isProvided('clothing')) 'clothing',
    if (!input.isProvided('maintenance')) 'maintenance',
    if (!input.isProvided('familyFun')) 'familyFun',
    if (!input.isProvided('other')) 'other',
  ];

  int aiValue(String key) {
    switch (key) {
      case 'rent': return ai.rent;
      case 'utilities': return ai.utilities;
      case 'food': return ai.food;
      case 'transport': return ai.transport;
      case 'debt': return ai.debt;
      case 'health': return ai.health;
      case 'clothing': return ai.clothing;
      case 'maintenance': return ai.maintenance;
      case 'familyFun': return ai.familyFun;
      case 'other': return ai.other;
      default: return 0;
    }
  }

  final available = (input.monthlyIncome - input.knownMandatoryTotal - input.knownFlexibleTotal)
      .clamp(0, 0x7fffffffffffffff);
  final safeReserve = ai.reserve.clamp(0, available);
  final categoryCap = (available - safeReserve).clamp(0, 0x7fffffffffffffff);
  final total = missing.fold<int>(0, (sum, key) => sum + aiValue(key));
  final scale = total > categoryCap && total > 0 ? categoryCap / total : 1.0;

  int bounded(String key) => (aiValue(key) * scale).floor().clamp(0, 0x7fffffffffffffff);

  final safe = HouseholdBudgetAiRecommendation(
    rent: input.isProvided('rent') ? ai.rent : bounded('rent'),
    utilities: input.isProvided('utilities') ? ai.utilities : bounded('utilities'),
    food: input.isProvided('food') ? ai.food : bounded('food'),
    transport: input.isProvided('transport') ? ai.transport : bounded('transport'),
    debt: input.isProvided('debt') ? ai.debt : bounded('debt'),
    health: input.isProvided('health') ? ai.health : bounded('health'),
    clothing: input.isProvided('clothing') ? ai.clothing : bounded('clothing'),
    maintenance: input.isProvided('maintenance') ? ai.maintenance : bounded('maintenance'),
    familyFun: input.isProvided('familyFun') ? ai.familyFun : bounded('familyFun'),
    other: input.isProvided('other') ? ai.other : bounded('other'),
    reserve: safeReserve,
    managerMessage: ai.managerMessage,
    recommendation: ai.recommendation,
  );

  return HouseholdBudgetInput(
    monthlyIncome: input.monthlyIncome,
    rent: input.rent,
    utilities: input.utilities,
    food: input.food,
    transport: input.transport,
    debt: input.debt,
    health: input.health,
    clothing: input.clothing,
    maintenance: input.maintenance,
    familyFun: input.familyFun,
    other: input.other,
    savingsTarget: input.savingsTarget,
    providedFields: input.providedFields,
    aiRecommendation: safe,
  );
}

HouseholdBudgetManagement _management(HouseholdBudgetInput input, int reserve, int weeklyAllowance) {
  final aiMessage = input.aiRecommendation?.managerMessage;
  return buildHouseholdBudgetManagement(
    rent: input.effectiveRent,
    utilities: input.effectiveUtilities,
    food: input.effectiveFood,
    transport: input.effectiveTransport,
    debt: input.effectiveDebt,
    health: input.effectiveHealth,
    clothing: input.effectiveClothing,
    maintenance: input.effectiveMaintenance,
    familyFun: input.effectiveFamilyFun,
    other: input.effectiveOther,
    reserve: reserve,
    weeklyRoom: weeklyAllowance,
    knownFood: input.isProvided('food') ? input.food : 0,
    knownClothing: input.isProvided('clothing') ? input.clothing : 0,
    knownMaintenance: input.isProvided('maintenance') ? input.maintenance : 0,
    knownFamilyFun: input.isProvided('familyFun') ? input.familyFun : 0,
    knownOther: input.isProvided('other') ? input.other : 0,
    managerMessageOverride: aiMessage?.isNotEmpty == true ? aiMessage : null,
  );
}