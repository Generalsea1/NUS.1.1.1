import '../../../core/ai/ai_insight.dart';
import '../../finance/application/financial_advisor_provider.dart';

/// Thin Copilot-facing boundary around the already verified read-only
/// FinancialAdvisorProvider. Keeping this wrapper small lets the Copilot evolve
/// without coupling its UI to a provider SDK or transport implementation.
class FinancialCopilotProvider {
  FinancialCopilotProvider({FinancialAdvisorProvider? advisor})
      : _advisor = advisor ?? const FinancialAdvisorProvider();

  final FinancialAdvisorProvider _advisor;

  Future<AiInsight> generateInsight(AiInsightRequest request) =>
      _advisor.generateInsight(request);
}
