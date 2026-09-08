import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/features/finance/application/financial_advisor_provider.dart';

class _RecordingTransport implements FinancialAdvisorTransport {
  _RecordingTransport(this.response);
  final FinancialAdvisorTransportResponse response;
  String? accessToken;
  Map<String, dynamic>? body;

  @override
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    this.accessToken = accessToken;
    this.body = body;
    return response;
  }
}

class _ThrowingTransport implements FinancialAdvisorTransport {
  _ThrowingTransport(this.error);
  final FinancialAdvisorException error;

  @override
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    throw error;
  }
}

AiInsightRequest _request() => const AiInsightRequest(
      objective: 'User question: أين يذهب إنفاقي؟',
      context: [
        AiContextItem(
          domain: 'financial_engine',
          entityId: 'monthly:2026-09',
          summary:
              'income=10000;obligations=2500;actualExpensesMinor=180000;expectedRecurringMinor=90000;actualPositionMinor=820000;positionAfterObligations=7500;currency=EGP;actualByCategory=food:120000|transport:60000',
        ),
      ],
    );

Map<String, dynamic> _successResponse() => {
      'ok': true,
      'id': 'advisor-1',
      'generatedAt': '2026-09-08T11:00:00.000Z',
      'summary': 'راجع بند الإنفاق الأعلى أولًا.',
      'facts': ['income=10000;obligations=2500'],
      'advice': ['ابدأ بمراجعة المصروفات المتغيرة.'],
      'warnings': <String>[],
    };

void main() {
  test('provider sends authoritative Financial Engine context unchanged', () async {
    final transport = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    final provider = FinancialAdvisorProvider(
      transport: transport,
      accessTokenReader: () => 'test-user-token',
    );

    final request = _request();
    final result = await provider.generateInsight(request);

    expect(result.sourceDomain, 'financial_advisor');
    expect(transport.accessToken, 'test-user-token');
    expect(transport.body?['objective'], request.objective);
    expect(transport.body?['context'], [
      {
        'domain': 'financial_engine',
        'entityId': 'monthly:2026-09',
        'summary': request.context.single.summary,
      },
    ]);
  });

  test('provider is read-only: it has no financial repository and only transports supplied data', () async {
    final transport = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    final provider = FinancialAdvisorProvider(
      transport: transport,
      accessTokenReader: () => 'test-user-token',
    );

    final before = _request().context.single.summary;
    await provider.generateInsight(_request());
    final after = _request().context.single.summary;

    expect(after, before);
    expect(transport.body?['context'].toString(), contains('income=10000'));
    expect(transport.body?['context'].toString(), contains('obligations=2500'));
    expect(transport.body?['context'].toString(), contains('actualExpensesMinor=180000'));
  });

  test('structured response parses correctly', () async {
    final provider = FinancialAdvisorProvider(
      transport: _RecordingTransport(
        FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
      ),
      accessTokenReader: () => 'test-user-token',
    );

    final result = await provider.generateInsight(_request());
    expect(result.id, 'advisor-1');
    expect(result.summary, contains('راجع بند الإنفاق الأعلى أولًا.'));
    expect(result.summary, contains('الحقائق'));
    expect(result.summary, contains('النصيحة'));
  });

  test('malformed response fails safely', () async {
    final provider = FinancialAdvisorProvider(
      transport: _RecordingTransport(
        const FinancialAdvisorTransportResponse(
          statusCode: 200,
          data: {'ok': true, 'summary': 'missing required fields'},
        ),
      ),
      accessTokenReader: () => 'test-user-token',
    );

    await expectLater(
      provider.generateInsight(_request()),
      throwsA(isA<FinancialAdvisorException>().having(
        (error) => error.kind,
        'kind',
        FinancialAdvisorFailureKind.malformedResponse,
      )),
    );
  });

  test('authentication is required before transport invocation', () async {
    final transport = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    final provider = FinancialAdvisorProvider(
      transport: transport,
      accessTokenReader: () => null,
    );

    await expectLater(
      provider.generateInsight(_request()),
      throwsA(isA<FinancialAdvisorException>().having(
        (error) => error.kind,
        'kind',
        FinancialAdvisorFailureKind.authentication,
      )),
    );
    expect(transport.accessToken, isNull);
  });

  test('backend failure kinds remain explicit', () async {
    final cases = <int, FinancialAdvisorFailureKind>{
      401: FinancialAdvisorFailureKind.authentication,
      409: FinancialAdvisorFailureKind.providerUnavailable,
      429: FinancialAdvisorFailureKind.rateLimited,
      422: FinancialAdvisorFailureKind.malformedResponse,
      502: FinancialAdvisorFailureKind.providerUnavailable,
      503: FinancialAdvisorFailureKind.backendUnavailable,
      504: FinancialAdvisorFailureKind.timeout,
    };

    for (final entry in cases.entries) {
      final provider = FinancialAdvisorProvider(
        transport: _ThrowingTransport(
          FinancialAdvisorException(
            kind: entry.value,
            statusCode: entry.key,
            message: 'test failure',
          ),
        ),
        accessTokenReader: () => 'test-user-token',
      );
      await expectLater(
        provider.generateInsight(_request()),
        throwsA(isA<FinancialAdvisorException>().having(
          (error) => error.kind,
          'kind',
          entry.value,
        )),
      );
    }
  });
}
