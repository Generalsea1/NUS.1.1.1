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

    final list = find.byType(ListView).first;
    await tester.fling(list, const Offset(0, -700), 1000);
    await tester.pumpAndSettle();

    final input = find.byType(TextField, skipOffstage: false);
    expect(input, findsOneWidget);
    await tester.ensureVisible(input);
    await tester.enterText(input, 'فين أكبر فرصة أوفر منها هذا الشهر؟');

    final submit = find.byTooltip('اسأل NUS', skipOffstage: false);
    expect(submit, findsOneWidget);
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('الخلاصة', skipOffstage: false), findsOneWidget);
    expect(find.text('الحقائق المستخدمة', skipOffstage: false), findsOneWidget);
    expect(find.text('أولويات التنفيذ', skipOffstage: false), findsOneWidget);
    expect(find.text('ملاحظات مهمة', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('وضع البيت يحتاج الحفاظ على السيولة', skipOffstage: false), findsOneWidget);
  });
}
