import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/installment_plan_repository.dart';
import 'package:nus/features/finance/application/installment_plan_service.dart';
import 'package:nus/features/finance/presentation/installment_planner_page.dart';
import 'package:nus/features/finance/domain/installment_plan.dart';

class _FakePlanRepository implements InstallmentPlanRepository {
  final List<InstallmentPlan> plans = [];

  @override
  Future<List<InstallmentPlan>> list(String userId) async => List.unmodifiable(plans);

  @override
  Future<InstallmentPlan> create(InstallmentPlan plan) async {
    plans.add(plan);
    return plan;
  }

  @override
  Future<InstallmentPlan> update(InstallmentPlan plan) async => plan;

  @override
  Future<void> delete(String userId, String planId) async {}
}

void main() {
  testWidgets('calculates and renders an installment schedule', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InstallmentPlannerPage(userId: 'u1', currencyCode: 'EGP'),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey<String>('installment-total')), '1000');
    await tester.enterText(find.byKey(const ValueKey<String>('installment-down-payment')), '0');
    await tester.enterText(find.byKey(const ValueKey<String>('installment-count')), '3');
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('installment-summary')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey<String>('installment-row-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('installment-row-2')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('installment-row-3')));
    await tester.pump();
    expect(find.textContaining('333.34 EGP'), findsOneWidget);
    expect(find.textContaining('333.33 EGP'), findsNWidgets(2));
  });

  testWidgets('preserves two decimal places without rounding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InstallmentPlannerPage(userId: 'u1', currencyCode: 'EGP'),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey<String>('installment-total')), '1000.75');
    await tester.enterText(find.byKey(const ValueKey<String>('installment-down-payment')), '0.75');
    await tester.enterText(find.byKey(const ValueKey<String>('installment-count')), '2');
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('installment-summary')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey<String>('installment-row-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey<String>('installment-row-2')));
    await tester.pump();
    expect(find.textContaining('500.00 EGP'), findsNWidgets(2));
  });

  testWidgets('requires explicit confirmation before saving a plan', (tester) async {
    final repository = _FakePlanRepository();
    final service = InstallmentPlanService(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: InstallmentPlannerPage(userId: 'u1', currencyCode: 'EGP', planService: service),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey<String>('installment-total')), '1200');
    await tester.enterText(find.byKey(const ValueKey<String>('installment-count')), '4');
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pumpAndSettle();

    final save = find.byKey(const ValueKey<String>('installment-save'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.plans, isEmpty);
    expect(find.text('حفظ خطة الأقساط؟'), findsOneWidget);

    await tester.tap(find.text('حفظ الخطة').last);
    await tester.pumpAndSettle();

    expect(repository.plans, hasLength(1));
    expect(repository.plans.single.totalMinorUnits, 120000);
    expect(find.text('تم حفظ الخطة'), findsOneWidget);
  });

  testWidgets('shows validation feedback for invalid values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InstallmentPlannerPage(userId: 'u1', currencyCode: 'EGP'),
      ),
    );
    await tester.enterText(find.byKey(const ValueKey<String>('installment-total')), '0');
    await tester.tap(find.byKey(const ValueKey<String>('installment-calculate')));
    await tester.pump();
    expect(find.textContaining('راجع المبلغ'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('installment-summary')), findsNothing);
  });
}
