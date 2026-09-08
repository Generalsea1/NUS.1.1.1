import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/core/ai/ai_insight_provider.dart';
import 'package:nus/features/finance/application/financial_advisor.dart';
import 'package:nus/features/finance/application/financial_advisor_provider.dart';
import 'package:nus/features/finance/application/financial_engine.dart';
import 'package:nus/features/finance/presentation/financial_advisor_page.dart';

FinancialAdvisorSnapshot _snapshot({
  int income = 10000,
  int obligations = 2500,
  int actual = 180000,
  int expected = 90000,
  int actualPosition = 820000,
  int positionAfterObligations = 7500,
  Map<String, int> categories = const {'food': 120000, 'transport': 60000},
}) => FinancialAdvisorSnapshot(
      financial: FinancialSnapshot(
        year: 2026,
        month: 9,
        currencyCode: 'EGP',
        monthlyIncome: income,
        monthlyObligations: obligations,
        actualExpensesMinorUnits: actual,
        expectedRecurringExpensesMinorUnits: expected,
        actualPositionMinorUnits: actualPosition,
        positionAfterObligations: positionAfterObligations,
      ),
      actualByCategory: categories,
    );

class _FakeProvider implements AiInsightProvider {
  _FakeProvider(this.response);
  final String response;
  AiInsightRequest? request;

  @override
  Future<AiInsight> generateInsight(AiInsightRequest value) async {
    request = value;
    return AiInsight(
      id: 'insight-1',
      summary: response,
      generatedAt: DateTime.utc(2026, 9, 7),
      sourceDomain: 'financial_engine',
    );
  }
}

class _FailingProvider implements AiInsightProvider {
  const _FailingProvider();
  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    throw const FinancialAdvisorUnavailableException('unavailable');
  }
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  final advisorScrollables = find.descendant(
    of: find.byType(FinancialAdvisorPage),
    matching: find.byType(Scrollable),
  );
  expect(advisorScrollables, findsOneWidget);
  await tester.scrollUntilVisible(
    finder,
    500,
    scrollable: advisorScrollables,
  );
}

void main() {
  test('snapshot exposes income, obligations, actual and expected values separately', () {
    final snapshot = _snapshot();
    final request = snapshot.toAiRequest();
    expect(request.context, hasLength(1));
    final summary = request.context.single.summary;
    expect(summary, contains('income=10000'));
    expect(summary, contains('obligations=2500'));
    expect(summary, contains('actualExpensesMinor=180000'));
    expect(summary, contains('expectedRecurringMinor=90000'));
    expect(summary, contains('actualPositionMinor=820000'));
    expect(summary, contains('positionAfterObligations=7500'));
    expect(summary, contains('actualByCategory=food:120000|transport:60000'));
  });

  test('snapshot never creates a combined obligation plus actual payment total', () {
    final snapshot = _snapshot(obligations: 3000, actualPosition: 820000, positionAfterObligations: 7000);
    final summary = snapshot.toAiRequest().context.single.summary;
    expect(summary, isNot(contains('combinedExpenses')));
    expect(snapshot.financial.actualPositionMinorUnits, 820000);
    expect(snapshot.financial.positionAfterObligations, 7000);
  });

  testWidgets('successful advisor response displays the supplied provider answer', (tester) async {
    final provider = _FakeProvider('FACTS: المصروفات الفعلية 180000 وحدة صغرى. ADVICE: راجع بند الطعام.');
    await tester.pumpWidget(MaterialApp(
      home: FinancialAdvisorPage(snapshot: _snapshot(), provider: provider),
    ));
    final questionInput = find.byKey(const ValueKey<String>('advisor-question-input'));
    final askButton = find.byKey(const ValueKey<String>('advisor-ask-button'));
    await _scrollUntilVisible(tester, questionInput);
    await tester.enterText(questionInput, 'أين يذهب معظم إنفاقي؟');
    await _scrollUntilVisible(tester, askButton);
    await tester.tap(askButton);
    await tester.pumpAndSettle();
    final responseState = find.byKey(const ValueKey<String>('advisor-response-state'));
    await _scrollUntilVisible(tester, responseState);
    expect(responseState, findsOneWidget);
    expect(find.textContaining('راجع بند الطعام'), findsOneWidget);
    expect(provider.request, isNotNull);
    expect(provider.request!.context.single.domain, 'financial_engine');
    expect(provider.request!.context.single.summary, contains('actualByCategory=food:120000|transport:60000'));
  });

  testWidgets('advisor unavailable state keeps the UI usable and financial data unchanged', (tester) async {
    final snapshot = _snapshot();
    await tester.pumpWidget(MaterialApp(
      home: FinancialAdvisorPage(snapshot: snapshot, provider: const _FailingProvider()),
    ));
    final questionInput = find.byKey(const ValueKey<String>('advisor-question-input'));
    final askButton = find.byKey(const ValueKey<String>('advisor-ask-button'));
    await _scrollUntilVisible(tester, questionInput);
    await tester.enterText(questionInput, 'هل وضعي المالي أفضل؟');
    await _scrollUntilVisible(tester, askButton);
    await tester.tap(askButton);
    await tester.pumpAndSettle();
    final errorState = find.byKey(const ValueKey<String>('advisor-error-state'));
    await _scrollUntilVisible(tester, errorState);
    expect(errorState, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('advisor-question-input')), findsOneWidget);
    expect(snapshot.financial.monthlyIncome, 10000);
    expect(snapshot.financial.monthlyObligations, 2500);
    expect(snapshot.financial.actualExpensesMinorUnits, 180000);
  });

  testWidgets('empty financial data shows a clear empty state without inventing values', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FinancialAdvisorPage(
        snapshot: _snapshot(
          income: 0,
          obligations: 0,
          actual: 0,
          expected: 0,
          actualPosition: 0,
          positionAfterObligations: 0,
          categories: const {},
        ),
        provider: const _FailingProvider(),
      ),
    ));
    final emptyState = find.byKey(const ValueKey<String>('advisor-empty-state'));
    await _scrollUntilVisible(tester, emptyState);
    expect(emptyState, findsOneWidget);
    expect(find.textContaining('اكتب سؤالك'), findsOneWidget);
  });
}
