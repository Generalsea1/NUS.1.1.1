/// Compares the household manager's planned monthly spend with the
/// amount actually recorded in the expense ledger for the same month.
class HouseholdBudgetActualComparison {
  const HouseholdBudgetActualComparison({
    required this.plannedAmount,
    required this.actualAmount,
  });

  final int plannedAmount;
  final int actualAmount;

  int get variance => plannedAmount - actualAmount;

  bool get isOverPlan => actualAmount > plannedAmount;

  bool get isOnOrUnderPlan => actualAmount <= plannedAmount;

  /// Positive percentage means the household is still below plan; negative
  /// percentage means the recorded spend is already above plan.
  double get progressPercent {
    if (plannedAmount <= 0) {
      return actualAmount <= 0 ? 0 : 100;
    }
    return (actualAmount / plannedAmount) * 100;
  }

  String get managerMessage {
    if (plannedAmount <= 0) {
      return actualAmount > 0
          ? 'فيه مصروفات فعلية من غير ميزانية شهرية مقابلة لها.'
          : 'لسه مفيش إنفاق فعلي أو خطة شهرية للمقارنة.';
    }
    if (isOverPlan) {
      return 'المصروف الفعلي عدى الخطة. مدير المنزل ينصح بوقف المصروفات المرنة مؤقتًا ومراجعة البنود الأعلى استهلاكًا.';
    }
    if (actualAmount == plannedAmount) {
      return 'أنت وصلت لسقف الخطة تقريبًا. أي مصروف إضافي يحتاج مراجعة الأولويات.';
    }
    return 'الإنفاق الفعلي ما زال داخل الخطة. حافظ على السقف الأسبوعي ولا تعتبر المتبقي مبلغًا متاحًا بالكامل.';
  }
}
