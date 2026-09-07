import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';

class FinancialAdvisorUnavailableException implements Exception {
  const FinancialAdvisorUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Production-safe adapter until a read-only advisor generation endpoint exists.
/// It intentionally does not fall back to the budget-planning AI because that
/// provider can persist financial context and is not an advisor contract.
class FinancialAdvisorProvider implements AiInsightProvider {
  const FinancialAdvisorProvider();

  @override
  Future<AiInsight> generateInsight(AiInsightRequest request) async {
    throw const FinancialAdvisorUnavailableException(
      'المستشار المالي بالذكاء الاصطناعي غير متاح حاليًا. بياناتك المالية تعمل بشكل طبيعي بدون الذكاء الاصطناعي.',
    );
  }
}
