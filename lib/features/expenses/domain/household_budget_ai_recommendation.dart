/// Structured, provider-neutral result returned by the household-budget AI.
class HouseholdBudgetAiRecommendation {
  const HouseholdBudgetAiRecommendation({
    required this.food,
    required this.clothing,
    required this.maintenance,
    required this.familyFun,
    required this.other,
    required this.reserve,
    required this.managerMessage,
    required this.recommendation,
  });

  final int food;
  final int clothing;
  final int maintenance;
  final int familyFun;
  final int other;
  final int reserve;
  final String managerMessage;
  final String recommendation;

  factory HouseholdBudgetAiRecommendation.fromJson(Map<String, dynamic> json) {
    int amount(String key) {
      final value = json[key];
      if (value is num) return value.round();
      return int.tryParse('$value') ?? 0;
    }

    String text(String key) => (json[key] as String? ?? '').trim();

    return HouseholdBudgetAiRecommendation(
      food: amount('food'),
      clothing: amount('clothing'),
      maintenance: amount('maintenance'),
      familyFun: amount('familyFun'),
      other: amount('other'),
      reserve: amount('reserve'),
      managerMessage: text('managerMessage'),
      recommendation: text('recommendation'),
    );
  }

  Map<String, dynamic> toJson() => {
        'food': food,
        'clothing': clothing,
        'maintenance': maintenance,
        'familyFun': familyFun,
        'other': other,
        'reserve': reserve,
        'managerMessage': managerMessage,
        'recommendation': recommendation,
      };
}
