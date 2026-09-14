import 'package:flutter/material.dart';

import '../../expenses/application/expense_management_service.dart';
import '../../expenses/data/supabase_expense_repository.dart';
import '../../expenses/data/supabase_recurring_expense_repository.dart';
import '../../finance/presentation/nus_financial_home_page.dart';
import '../../onboarding/domain/household_profile.dart';

/// Backward-compatible entry point for legacy imports.
/// Production navigation uses [NusFinancialHomePage] directly.
class NusTodayPage extends NusFinancialHomePage {
  NusTodayPage({
    super.key,
    required HouseholdProfile profile,
    Object? scheduleStore,
    VoidCallback? onSignOut,
    ExpenseManagementService? expenseManagementService,
  }) : super(
          profile: profile,
          expenseManagementService: expenseManagementService ??
              const ExpenseManagementService(
                expenseRepository: SupabaseExpenseRepository(),
                recurringRepository: SupabaseRecurringExpenseRepository(),
              ),
          onSignOut: onSignOut,
        );

  // Kept in the constructor for source compatibility with older callers.
  // It is intentionally ignored because scheduling is no longer part of the
  // authenticated financial command-center surface.
}