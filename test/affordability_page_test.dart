import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/affordability_service.dart';
import 'package:nus/features/finance/domain/affordability.dart';
import 'package:nus/features/finance/presentation/affordability_page.dart';

class _FakeAffordabilityService implements AffordabilityService {
  int? lastScenarioMonths;
  bool? lastRecurring;

  @override
  Future<AffordabilityAssessment> assess({
    required String userId,
    required int year,
    required int month,
    required String currencyCode,
    required int proposedMinorUnits,
    required bool recurring,
    int scenarioMonths = 1,
  }) async {
    lastRecurring = recurring;
    lastScenarioMonths = scenarioMonths;
    return AffordabilityAssessment(
      status: AffordabilityStatus.affordable,
      currencyCode: currencyCode,
      proposedMinorUnits: proposedMinorUnits,
      monthlyIncomeMinorUnits: 1000000,
      monthlyObligationsMinorUnits: 200000,
      existingActualExpensesMinorUnits: 100000,
      resultingFreeCashMinorUnits: 600000,
      horizonMonths: recurring ? scenarioMonths : 1,
      minimumProjectedFreeCashMinorUnits: 600000,
    );
  }
}

void main() {
  testWidgets('recurring affordability exposes and sends scenario horizon', (tester) async {
    final service = _FakeAffordabilityService();
    await tester.pumpWidget(
      MaterialApp(
        home: AffordabilityPage(
          userId: 'u1',
          year: 2026,
          month: 9,
          currencyCode: 'EGP',
          service: service,
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey<String>('affordability-amount-input')), '1000.50');
    await tester.tap(find.byKey(const ValueKey<String>('affordability-recurring-toggle')));
    await tester.pump();

    final scenario = find.byKey(const ValueKey<String>('affordability-scenario-months'));
    await tester.ensureVisible(scenario);
    await tester.pump();
    expect(scenario, findsOneWidget);

    await tester.tap(scenario);
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 شهور').last);

    final assess = find.byKey(const ValueKey<String>('affordability-assess-button'));
    await tester.ensureVisible(assess);
    await tester.pump();
    await tester.tap(assess);
    await tester.pumpAndSettle();

    expect(service.lastRecurring, isTrue);
    expect(service.lastScenarioMonths, 6);
    expect(find.byKey(const ValueKey<String>('affordability-result')), findsOneWidget);
    expect(find.textContaining('أقل سيولة في السيناريو'), findsOneWidget);
  });
}
