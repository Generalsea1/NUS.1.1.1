import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/presentation/installment_planner_page.dart';

void main() {
  testWidgets('calculates and renders an installment schedule', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InstallmentPlannerPage(
          userId: 'u1',
          currencyCode: 'EGP',
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('installment-total')),
      '1001',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('installment-down-payment')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('installment-count')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('installment-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('installment-row-1')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('installment-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('installment-row-3')), findsOneWidget);
    expect(find.textContaining('334 EGP'), findsOneWidget);
    expect(find.textContaining('333 EGP'), findsNWidgets(2));
  });

  testWidgets('shows validation feedback for invalid values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InstallmentPlannerPage(
          userId: 'u1',
          currencyCode: 'EGP',
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('installment-total')),
      '0',
    );
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pump();

    expect(find.textContaining('راجع المبلغ'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('installment-summary')), findsNothing);
  });
}
