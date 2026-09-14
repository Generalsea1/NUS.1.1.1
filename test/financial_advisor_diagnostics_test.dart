import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/diagnostics/financial_advisor_diagnostics.dart';

void main() {
  final diagnostics = FinancialAdvisorDiagnostics.instance;

  setUp(() => diagnostics.clear());

  test('sanitizes bearer, api, access, refresh and cookie secrets without backreference artifacts', () {
    diagnostics.record(
      'Bearer abc.def-123 api_key=secret-key access_token=access-value refresh_token=refresh-value cookie=session-cookie',
    );

    final line = diagnostics.events.single.line;
    expect(line, 'Bearer [REDACTED] api_key=[REDACTED] access_token=[REDACTED] refresh_token=[REDACTED] cookie=[REDACTED]');
    expect(line, isNot(contains(r'\1')));
    expect(line, isNot(contains('secret-key')));
    expect(line, isNot(contains('access-value')));
    expect(line, isNot(contains('refresh-value')));
    expect(line, isNot(contains('session-cookie')));
  });

  test('redacts Gemini API keys', () {
    diagnostics.record('provider=gemini key=AIzaSyBCDEFGHIJKLMNOPQRSTUVWX');

    final line = diagnostics.events.single.line;
    expect(line, contains('[REDACTED_API_KEY]'));
    expect(line, isNot(contains('AIzaSyBCDEFGHIJKLMNOPQRSTUVWX')));
  });
}
