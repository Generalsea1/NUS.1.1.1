import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/core/ai/ai_insight_provider.dart';
import 'package:nus/features/finance/application/financial_advisor.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/finance/presentation/ask_nus_page.dart';

class _FakeProvider implements AiInsightProvider {
  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    return AiInsight(
      id: 'test',
      summary: 'الخلاصة: وضع البيت يحتاج الحفاظ على السيولة.',
      generatedAt: DateTime(2026, 9, 14),
      sourceDomain: 'financial_engine',
      facts: const <String>['الدخل 20000 EGP', 'المصروف الفعلي 9000 EGP'],
      advice: const <String>['ثبّت المصروفات الأساسية أولًا', 'أجل الالتزام غير الضروري'],
      warnings: const <String>['لا تعتمد على دخل غير مؤكد'],
    );
  }
}

FinancialAdvisorSnapshot _snapshot() {
  return FinancialAdvisorSnapshot(
    financial: const FinancialSnapshot(
      year: 2026,
      month: 9,
      currencyCode: 'EGP',
      monthlyIncome: 20000,
      monthlyObligations: 5000,
      actualExpensesMinorUnits: 900000,
      expectedRecurringExpensesMinorUnits: 150000,
      actualPositionMinorUnits: 1100000,
      positionAfterObligations: 15000,
    ),
    actualByCategory: const <String, int>{
      'الغذاء': 300000,
      'السكن': 400000,
      'المواصلات': 200000,
    },
  );
}

void main() {
  testWidgets('Ask NUS presents a structured financial command view', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AskNusPage(
          snapshot: _snapshot(),
          provider: _FakeProvider(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اسأل NUS'), findsNWidgets(2));
    expect(find.textContaining('المصروف الفعلي'), findsOneWidget);
    expect(find.text('الالتزامات', skipOffstage: false), findsOneWidget);
    expect(find.text('اختار السؤال الأسرع', skipOffstage: false), findsOneWidget);
    expect(find.text('ضع مفتاح'), findsNothing);
    expect(find.textContaining('Gemini'), findsNothing);

    final input = find.byType(TextField);
    expect(input, findsOneWidget);
    await tester.enterText(input, 'فين أكبر فرصة أوفر منها هذا الشهر؟');

    final submit = find.byTooltip('اسأل NUS');
    expect(submit, findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('الخلاصة'), findsOneWidget);
    expect(find.text('الحقائق المستخدمة'), findsOneWidget);
    expect(find.text('أولويات التنفيذ'), findsOneWidget);
    expect(find.text('ملاحظات مهمة'), findsOneWidget);
    expect(find.textContaining('لا تعتمد على دخل غير مؤكد'), findsOneWidget);
  });
}
