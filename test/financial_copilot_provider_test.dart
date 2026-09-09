import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/features/ai/application/financial_copilot_provider.dart';
import 'package:nus/features/finance/application/financial_advisor_provider.dart';

class _FakeTransport implements FinancialAdvisorTransport {
  Map<String, dynamic>? capturedBody;

  @override
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    capturedBody = body;
    return FinancialAdvisorTransportResponse(
      statusCode: 200,
      data: {
        'ok': true,
        'id': 'copilot-test-1',
        'summary': 'اختبرنا المساعد المالي بنجاح.',
        'generatedAt': '2026-09-09T10:00:00Z',
        'facts': ['الدخل معروف.'],
        'advice': ['اتخذ القرار بعد مراجعة الالتزامات.'],
        'warnings': <String>[],
      },
    );
  }
}

void main() {
  test('delegates provider-neutral request to the existing financial advisor', () async {
    final transport = _FakeTransport();
    final advisor = FinancialAdvisorProvider(
      transport: transport,
      accessTokenReader: () => 'test-token',
    );
    final provider = FinancialCopilotProvider(advisor: advisor);

    final insight = await provider.generateInsight(
      const AiInsightRequest(
        objective: 'ينفع أشتري جهاز جديد؟',
        context: [
          AiContextItem(
            domain: 'household_profile',
            entityId: 'current_household',
            summary: 'currency=EGP; monthlyIncome=30000; recurringObligations=18000; remainingAfterObligations=12000',
          ),
        ],
      ),
    );

    expect(insight.sourceDomain, 'financial_advisor');
    expect(insight.id, 'copilot-test-1');
    expect(insight.summary, contains('اختبرنا المساعد المالي بنجاح'));
    expect(transport.capturedBody?['objective'], 'ينفع أشتري جهاز جديد؟');
  });
}
