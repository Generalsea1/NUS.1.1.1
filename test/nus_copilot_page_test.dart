import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/core/ai/ai_insight_provider.dart';
import 'package:nus/features/ai/presentation/nus_copilot_page.dart';

class _FakeAiProvider implements AiInsightProvider {
  AiInsightRequest? request;

  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    this.request = request;
    return AiInsight(
      id: 'i1',
      summary: 'رد تجريبي',
      generatedAt: DateTime(2026, 9, 9, 10),
      sourceDomain: 'test',
    );
  }
}

void main() {
  testWidgets('Copilot sends composed cross-domain context through provider boundary', (tester) async {
    final provider = _FakeAiProvider();
    final request = const AiInsightRequest(
      objective: 'ساعدني أنظم يومي',
      context: [
        AiContextItem(domain: 'household', entityId: 'home', summary: '3 أفراد'),
        AiContextItem(domain: 'calendar', entityId: 'next', summary: 'كشف طبي 10:00'),
        AiContextItem(domain: 'shopping', entityId: 'pending', summary: '4 عناصر'),
        AiContextItem(domain: 'finance', entityId: 'month', summary: 'دخل 10000 EGP'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NusCopilotPage(
          provider: provider,
          contextBuilder: (_) async => request,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('copilot-question-input')),
      'إيه أهم حاجة أعملها؟',
    );
    await tester.tap(find.byKey(const ValueKey<String>('copilot-ask-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('copilot-response')), findsOneWidget);
    expect(find.text('رد تجريبي'), findsOneWidget);
    expect(provider.request, isNotNull);
    expect(provider.request!.context.map((item) => item.domain), containsAll(<String>[
      'household',
      'calendar',
      'shopping',
      'finance',
    ]));
    expect(provider.request!.objective, 'ساعدني أنظم يومي');
  });
}
