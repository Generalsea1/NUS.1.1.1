import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/today/domain/nus_daily_intelligence.dart';

void main() {
  test('surfaces a reminder as the next thing today', () {
    final profile = HouseholdProfile(
      userId: 'user-1',
      countryCode: 'EG',
      region: 'Cairo',
      currencyCode: 'EGP',
      householdSize: 3,
      adults: 2,
      children: 1,
      housingType: 'rent',
      incomeFrequency: 'monthly',
      monthlyIncome: 10000,
      recurringObligations: 3000,
    );

    final insights = NusDailyIntelligence.build(
      profile: profile,
      appointments: const [],
      pendingReminderCount: 1,
      nextReminderTitle: 'دفع الكهرباء',
      nextReminderAt: DateTime(2026, 9, 9, 15),
      now: DateTime(2026, 9, 9, 13),
    );

    expect(insights.any((item) => item.title == 'عندك مهمة جاية النهارده'), isTrue);
    expect(insights.any((item) => item.message.contains('دفع الكهرباء')), isTrue);
  });

  test('counts appointments and reminders together for workload', () {
    final profile = HouseholdProfile(
      userId: 'user-1',
      countryCode: 'EG',
      region: 'Cairo',
      currencyCode: 'EGP',
      householdSize: 3,
      adults: 2,
      children: 1,
      housingType: 'rent',
      incomeFrequency: 'monthly',
      monthlyIncome: 10000,
      recurringObligations: 3000,
    );

    final insights = NusDailyIntelligence.build(
      profile: profile,
      appointments: const [],
      pendingReminderCount: 3,
      now: DateTime(2026, 9, 9, 13),
    );

    expect(insights.any((item) => item.title == 'الأسبوع محتاج تنظيم'), isTrue);
    expect(insights.any((item) => item.message.contains('3 موعد أو مهمة')), isTrue);
  });
}
