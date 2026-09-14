import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/today/presentation/nus_today_page.dart';

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
  testWidgets('legacy Today entry point renders the financial command center', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NusTodayPage(profile: _profile()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NUS'), findsOneWidget);
    expect(find.text('اقتصاد البيت تحت السيطرة'), findsOneWidget);
    expect(find.byTooltip('اسأل NUS'), findsOneWidget);
    expect(find.text('NUS Copilot'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}