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

AiInsightRequest _request() => const AiInsightRequest(
      objective: 'User question: أين يذهب إنفاقي؟',
      context: [
        AiContextItem(
          domain: 'financial_engine',
          entityId: 'monthly:2026-09',
          summary:
              'income=10000;obligations=2500;actualExpensesMinor=180000;expectedRecurringMinor=90000;currency=EGP;actualByCategory=food:120000|transport:60000',
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
  test('provider sends the Financial Engine request unchanged and requires authentication', () async {
    final transport = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    const provider = FinancialAdvisorProvider(
      transport: null,
      accessTokenReader: _token,
    );

    final actual = await provider.generateInsight(_request());

    expect(transport.body, isNull);
    expect(actual.sourceDomain, 'financial_advisor');

    final injected = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    final injectedProvider = FinancialAdvisorProvider(
      transport: injected,
      accessTokenReader: _token,
    );
    await injectedProvider.generateInsight(_request());

    expect(injected.accessToken, 'test-user-token');
    expect(injected.body?['objective'], _request().objective);
    expect(injected.body?['context'], [
      {
        'domain': 'financial_engine',
        'entityId': 'monthly:2026-09',
        'summary': _request().context.single.summary,
      },
    ]);
  });

  test('provider is read-only and does not call any financial repository', () async {
    final transport = _RecordingTransport(
      FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
    );
    final provider = FinancialAdvisorProvider(
      transport: transport,
      accessTokenReader: _token,
    );

    final snapshot = _request().context.single.summary;
    await provider.generateInsight(_request());

    expect(snapshot, contains('income=10000'));
    expect(snapshot, contains('obligations=2500'));
    expect(snapshot, contains('actualExpensesMinor=180000'));
  });

  test('structured response parses facts, advice and warnings', () async {
    final provider = FinancialAdvisorProvider(
      transport: _RecordingTransport(
        FinancialAdvisorTransportResponse(statusCode: 200, data: _successResponse()),
      ),
      accessTokenReader: _token,
    );

    final result = await provider.generateInsight(_request());
    expect(result.summary, contains('راجع بند الإنفاق الأعلى أولًا.'));
    expect(result.summary, contains('الحقائق'));
    expect(result.summary, contains('النصيحة'));
  });

  test('malformed structured response fails safely', () async {
    final provider = FinancialAdvisorProvider(
      transport: _RecordingTransport(
        const FinancialAdvisorTransportResponse(
          statusCode: 200,
          data: {'ok': true, 'summary': 'missing required fields'},
        ),
      ),
      accessTokenReader: _token,
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
        transport: _ThrowingTransport(entry.key),
        accessTokenReader: _token,
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

String? _token() => 'test-user-token';

class _ThrowingTransport implements FinancialAdvisorTransport {
  _ThrowingTransport(this.statusCode);
  final int statusCode;

  @override
  Future<FinancialAdvisorTransportResponse> invoke({
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    throw _FakeFunctionException(statusCode);
  }
}

class _FakeFunctionException implements Exception {
  _FakeFunctionException(this.statusCode);
  final int statusCode;
}
