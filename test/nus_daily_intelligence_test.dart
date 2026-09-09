import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/appointments/domain/appointment.dart';
import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/today/domain/nus_daily_intelligence.dart';
import 'package:nus/features/today/domain/nus_household_daily_brief.dart';

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
  test('integrates the household daily brief as the primary Today insight', () {
    final insights = NusDailyIntelligence.build(
      profile: _profile(income: 5000, obligations: 7000),
      appointments: const [],
      now: DateTime(2026, 9, 9, 9),
    );

    expect(insights.first.title, 'النهارده محتاج حماية للسيولة');
    expect(insights.first.message, contains('راجع أقرب التزامات'));
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

    expect(insights.any((item) => item.title == 'المشتريات جاهزة للخطوة التالية'), isTrue);
    expect(insights.any((item) => item.message.contains('4 عنصر')), isTrue);
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

  test('daily brief prioritizes financial pressure over shopping', () {
    final brief = NusHouseholdDailyBrief.build(
      profile: _profile(),
      appointments: const [],
      pendingReminderCount: 0,
      pendingShoppingItemCount: 5,
      monthlyActualExpenseMinorUnits: 700000,
      monthlyIncomeMinorUnits: 1000000,
      monthlyObligationsMinorUnits: 400000,
      now: DateTime(2026, 9, 9, 9),
    );

    expect(brief.priority, 'مالي');
    expect(brief.headline, 'النهارده محتاج حماية للسيولة');
  });

  test('daily brief chooses organization when workload is heavy', () {
    final brief = NusHouseholdDailyBrief.build(
      profile: _profile(),
      appointments: [
        Appointment(
          id: 'a1',
          title: 'اجتماع',
          startsAt: DateTime(2026, 9, 9, 10),
        ),
      ],
      pendingReminderCount: 2,
      pendingShoppingItemCount: 0,
      monthlyActualExpenseMinorUnits: 100000,
      monthlyIncomeMinorUnits: 1000000,
      monthlyObligationsMinorUnits: 200000,
      now: DateTime(2026, 9, 9, 9),
    );

    expect(brief.priority, 'تنظيم');
    expect(brief.summary, contains('3'));
    expect(brief.action, contains('موعدك الأقرب'));
  });

  test('daily brief is deterministic for identical facts', () {
    final first = NusHouseholdDailyBrief.build(
      profile: _profile(),
      appointments: const [],
      pendingReminderCount: 1,
      pendingShoppingItemCount: 2,
      monthlyActualExpenseMinorUnits: 100000,
      monthlyIncomeMinorUnits: 1000000,
      monthlyObligationsMinorUnits: 200000,
      now: DateTime(2026, 9, 9, 9),
    );
    final second = NusHouseholdDailyBrief.build(
      profile: _profile(),
      appointments: const [],
      pendingReminderCount: 1,
      pendingShoppingItemCount: 2,
      monthlyActualExpenseMinorUnits: 100000,
      monthlyIncomeMinorUnits: 1000000,
      monthlyObligationsMinorUnits: 200000,
      now: DateTime(2026, 9, 9, 9),
    );

    expect(first.headline, second.headline);
    expect(first.summary, second.summary);
    expect(first.priority, second.priority);
    expect(first.action, second.action);
  });
}
