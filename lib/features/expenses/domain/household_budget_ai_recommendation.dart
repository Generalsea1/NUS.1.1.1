/// Structured, provider-neutral result returned by the household-budget AI.
class HouseholdBudgetAiRecommendation {
  const HouseholdBudgetAiRecommendation({
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
    required this.reserve,
    required this.managerMessage,
    required this.recommendation,
  });

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
  final int reserve;
  final String managerMessage;
  final String recommendation;

  factory HouseholdBudgetAiRecommendation.fromJson(Map<String, dynamic> json) {
    int amount(String key) {
      final value = json[key];
      if (value is num) return value.round().clamp(0, 0x7fffffffffffffff);
      return (int.tryParse('$value') ?? 0).clamp(0, 0x7fffffffffffffff);
    }

    String text(String key) => (json[key] as String? ?? '').trim();

    return HouseholdBudgetAiRecommendation(
      rent: amount('rent'),
      utilities: amount('utilities'),
      food: amount('food'),
      transport: amount('transport'),
      debt: amount('debt'),
      health: amount('health'),
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
        'rent': rent,
        'utilities': utilities,
        'food': food,
        'transport': transport,
        'debt': debt,
        'health': health,
        'clothing': clothing,
        'maintenance': maintenance,
        'familyFun': familyFun,
        'other': other,
        'reserve': reserve,
        'managerMessage': managerMessage,
        'recommendation': recommendation,
      };
}
