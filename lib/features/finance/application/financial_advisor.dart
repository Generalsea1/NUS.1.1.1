import '../../../core/ai/ai_insight.dart';
import '../../finance/application/financial_engine.dart';

class FinancialAdvisorSnapshot {
  const FinancialAdvisorSnapshot({
    required this.financial,
    required this.actualByCategory,
  });

  final FinancialSnapshot financial;
  final Map<String, int> actualByCategory;

  AiInsightRequest toAiRequest() {
    final categories = actualByCategory.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('|');
    return AiInsightRequest(
      objective:
          'Advise the household using supplied facts only. Separate FACTS from ADVICE. Never invent, estimate, override, or calculate financial numbers.',
      context: <AiContextItem>[
        AiContextItem(
          domain: 'financial_engine',
          entityId:
              'monthly:${financial.year}-${financial.month.toString().padLeft(2, '0')}',
          summary:
              'income=${financial.monthlyIncome}; obligations=${financial.monthlyObligations}; actualExpensesMinor=${financial.actualExpensesMinorUnits}; expectedRecurringMinor=${financial.expectedRecurringExpensesMinorUnits}; actualPositionMinor=${financial.actualPositionMinorUnits}; positionAfterObligations=${financial.positionAfterObligations}; currency=${financial.currencyCode}; actualByCategory=$categories',
        ),
      ],
    );
  }
}
