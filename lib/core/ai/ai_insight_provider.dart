import 'ai_insight.dart';

/// Provider adapter boundary for future NUS intelligence capabilities.
///
/// A later implementation may target an approved remote provider or local
/// model without changing domain/application code.
abstract interface class AiInsightProvider {
  Future<AiInsight> generateInsight(AiInsightRequest request);
}
