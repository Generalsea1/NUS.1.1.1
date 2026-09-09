import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/features/ai/application/nus_copilot_provider.dart';

class _FakeTransport implements NusCopilotTransport {
  _FakeTransport(this.response);
  final Map<String, dynamic> response;
  String? token;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> invoke({required String accessToken, required Map<String, dynamic> body}) async {
    token = accessToken;
    this.body = body;
    return response;
  }
}

AiInsightRequest _request() => const AiInsightRequest(
      objective: 'ما أهم حاجة أركز عليها النهارده؟',
      context: [
        AiContextItem(domain: 'household', entityId: 'current-household', summary: 'البيت: 4 أفراد، العملة EGP.'),
        AiContextItem(domain: 'shopping', entityId: 'pending-shopping', summary: 'عدد عناصر المشتريات غير المكتملة: 3.'),
      ],
    );

Map<String, dynamic> _success() => <String, dynamic>{
      'ok': true,
      'id': 'copilot-1',
      'generatedAt': '2026-09-09T18:00:00.000Z',
      'summary': 'ابدأ بالحاجة الأقرب لوقتك اليوم.',
      'facts': ['البيت: 4 أفراد، العملة EGP.', 'عدد عناصر المشتريات غير المكتملة: 3.'],
      'advice': ['راجع المواعيد ثم أنجز الضروري.'],
      'warnings': <String>[],
    };

void main() {
  test('sends bounded context through dedicated Copilot transport', () async {
    final transport = _FakeTransport(_success());
    final provider = NusCopilotProvider(transport: transport, accessTokenReader: () => 'token');
    final result = await provider.generateInsight(_request());

    expect(result.sourceDomain, 'nus_copilot');
    expect(transport.token, 'token');
    expect(transport.body?['context'], [
      {'domain': 'household', 'entityId': 'current-household', 'summary': 'البيت: 4 أفراد، العملة EGP.'},
      {'domain': 'shopping', 'entityId': 'pending-shopping', 'summary': 'عدد عناصر المشتريات غير المكتملة: 3.'},
    ]);
  });

  test('requires authentication before transport', () async {
    final transport = _FakeTransport(_success());
    final provider = NusCopilotProvider(transport: transport, accessTokenReader: () => null);
    await expectLater(provider.generateInsight(_request()), throwsA(isA<NusCopilotException>()));
    expect(transport.token, isNull);
  });

  test('rejects malformed successful responses', () async {
    final provider = NusCopilotProvider(
      transport: _FakeTransport(const {'ok': true, 'summary': 'missing'}),
      accessTokenReader: () => 'token',
    );
    await expectLater(provider.generateInsight(_request()), throwsA(isA<NusCopilotException>()));
  });
}
