class HouseholdProfile {
  const HouseholdProfile({
    required this.userId,
    required this.countryCode,
    required this.region,
    required this.currencyCode,
    required this.householdSize,
    required this.adults,
    required this.children,
    required this.housingType,
    required this.incomeFrequency,
    required this.monthlyIncome,
    required this.recurringObligations,
  });

  final String userId;
  final String countryCode;
  final String? region;
  final String currencyCode;
  final int householdSize;
  final int adults;
  final int children;
  final String housingType;
  final String incomeFrequency;
  final int monthlyIncome;
  final int recurringObligations;

  int get remainingAfterObligations => monthlyIncome - recurringObligations;

  bool get isFinanciallyUnderObligated => remainingAfterObligations >= 0;
}

class InitialFinancialSummary {
  const InitialFinancialSummary({
    required this.monthlyIncome,
    required this.recurringObligations,
    required this.remainingAfterObligations,
    required this.currencyCode,
  });

  factory InitialFinancialSummary.fromProfile(HouseholdProfile profile) =>
      InitialFinancialSummary(
        monthlyIncome: profile.monthlyIncome,
        recurringObligations: profile.recurringObligations,
        remainingAfterObligations: profile.remainingAfterObligations,
        currencyCode: profile.currencyCode,
      );

  final int monthlyIncome;
  final int recurringObligations;
  final int remainingAfterObligations;
  final String currencyCode;
}
