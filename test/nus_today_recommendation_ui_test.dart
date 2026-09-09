import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/today/presentation/nus_today_page.dart';
import 'package:nus/legacy_main.dart' as legacy;
import 'package:shared_preferences/shared_preferences.dart';

HouseholdProfile _profile() => const HouseholdProfile(
      userId: 'u1',
      countryCode: 'EG',
      region: 'Cairo',
      currencyCode: 'EGP',
      householdSize: 2,
      adults: 2,
      children: 0,
      housingType: 'rented',
      incomeFrequency: 'monthly',
      monthlyIncome: 1000,
      recurringObligations: 1500,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Today renders the proactive financial recommendation', (tester) async {
    final store = legacy.ScheduleStore();

    await tester.pumpWidget(
      MaterialApp(
        home: NusTodayPage(
          profile: _profile(),
          scheduleStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اقتراحات NUS دلوقتي'), findsOneWidget);
    expect(find.text('راجع فلوس الشهر'), findsOneWidget);
    expect(
      find.textContaining('قبل أي التزام جديد'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
