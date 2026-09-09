import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/today/domain/nus_daily_intelligence.dart';

HouseholdProfile _profile({int income = 10000, int obligations = 3000}) => HouseholdProfile(
      userId: 'user-1',
      countryCode: 'EG',
      region: 'Cairo',
      currencyCode: 'EGP',
      householdSize: 3,
      adults: 2,
      children: 1,
      housingType: 'rent',
      incomeFrequency: 'monthly',
      monthlyIncome: income,
      recurringObligations: obligations,
    );

void main() {
  test('flags negative remaining income without inventing values', () {
    final insights = NusDailyIntelligence.build(
      profile: _profile(income: 5000, obligations: 7000),
      appointments: const [],
      now: DateTime(2026, 9, 9, 9),
    );

    expect(insights.first.title, 'الميزانية محتاجة تركيز');
    expect(insights.first.message, contains('أعلى من الدخل المسجل'));
  });

  test('surfaces the next appointment today', () {
    final insights = NusDailyIntelligence.build(
      profile: _profile(),
      appointments: [
        Appointment(
          id: 'a1',
          title: 'كشف طبي',
          startsAt: DateTime(2026, 9, 9, 12),
          status: AppointmentStatus.upcoming,
        ),
      ],
      now: DateTime(2026, 9, 9, 9),
    );

    expect(insights.any((item) => item.title == 'عندك حاجة جاية النهارده'), isTrue);
    expect(insights.any((item) => item.message.contains('كشف طبي')), isTrue);
  });

  test('surfaces pending shopping as a cross-domain daily insight', () {
    final insights = NusDailyIntelligence.build(
      profile: _profile(),
      appointments: const [],
      pendingShoppingItemCount: 4,
      now: DateTime(2026, 9, 9, 9),
    );

    expect(insights.any((item) => item.title == 'قائمة المشتريات مستنياك'), isTrue);
    expect(insights.any((item) => item.message.contains('4 عناصر')), isTrue);
  });

  test('reports calendar overload when at least three appointments are upcoming', () {
    final appointments = List.generate(
      3,
      (index) => Appointment(
        id: 'a$index',
        title: 'موعد $index',
        startsAt: DateTime(2026, 9, 10 + index, 10),
        status: AppointmentStatus.upcoming,
      ),
    );

    final insights = NusDailyIntelligence.build(
      profile: _profile(),
      appointments: appointments,
      now: DateTime(2026, 9, 9, 9),
    );

    expect(insights.any((item) => item.title == 'الأسبوع محتاج تنظيم'), isTrue);
  });
}
