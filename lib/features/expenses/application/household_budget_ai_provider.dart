import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../domain/household_budget_ai_recommendation.dart';
import '../domain/household_budget_plan.dart';

/// Real AI adapter for the household expense manager.
///
/// The mobile app never receives or stores the LLM secret. It invokes the
/// authenticated Supabase Edge Function, which owns the provider credential.
class HouseholdBudgetAiProvider {
  const HouseholdBudgetAiProvider();

  Future<HouseholdBudgetAiRecommendation> generate({
    required HouseholdBudgetInput input,
    required int actualThisMonth,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const HouseholdBudgetAiException(
        'Supabase is not configured on this build. Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    if (client.auth.currentSession == null) {
      throw const HouseholdBudgetAiException(
        'The AI budget manager requires an authenticated NUS session.',
      );
    }

    try {
      final response = await client.functions.invoke(
        'household-budget-ai',
        body: {
          'income': input.monthlyIncome,
          'rent': input.rent,
          'utilities': input.utilities,
          'food': input.food,
          'transport': input.transport,
          'debt': input.debt,
          'health': input.health,
          'clothing': input.clothing,
          'maintenance': input.maintenance,
          'familyFun': input.familyFun,
          'other': input.other,
          'savingsTarget': input.savingsTarget,
          'actualThisMonth': actualThisMonth,
        },
        headers: {
          'Authorization': 'Bearer ${client.auth.currentSession!.accessToken}',
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const HouseholdBudgetAiException('AI returned an invalid response.');
      }

      final payload = Map<String, dynamic>.from(data);
      if (payload['ok'] != true) {
        throw HouseholdBudgetAiException(
          payload['error'] as String? ?? 'The AI budget manager failed.',
        );
      }

      final result = payload['recommendation'];
      if (result is! Map) {
        throw const HouseholdBudgetAiException('AI recommendation is missing.');
      }

      return HouseholdBudgetAiRecommendation.fromJson(
        Map<String, dynamic>.from(result),
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw HouseholdBudgetAiException(details['error'] as String);
      }
      throw HouseholdBudgetAiException(
        error.reasonPhrase ?? 'The household AI service is unavailable.',
      );
    }
  }
}

class HouseholdBudgetAiException implements Exception {
  const HouseholdBudgetAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
