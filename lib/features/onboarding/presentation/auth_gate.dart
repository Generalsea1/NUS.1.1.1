import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/supabase_auth_repository.dart';
import '../../../core/supabase_service.dart';
import '../../expenses/application/expense_lifecycle_service.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../expenses/data/supabase_expense_repository.dart';
import '../../expenses/data/supabase_recurring_expense_repository.dart';
import '../../income/application/income_source_repository.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../shopping/application/shopping_lifecycle_service.dart';
import '../application/household_profile_repository.dart';
import '../application/household_profile_validator.dart';
import '../data/supabase_household_profile_repository.dart';
import '../domain/household_profile.dart';
import 'auth_page.dart';
import 'household_onboarding_page.dart';
import '../../finance/presentation/nus_financial_home_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authRepository,
    this.profileRepository,
    this.incomeRepository,
    this.expenseService,
    this.expenseManagementService,
    this.shoppingService,
    this.onOpenGeneralHome,
    this.onCreateReminder,
    this.scheduleStore,
    this.taskService,
    this.obligationService,
  });

  final AuthRepository? authRepository;
  final HouseholdProfileRepository? profileRepository;
  final IncomeSourceRepository? incomeRepository;
  final ExpenseLifecycleService? expenseService;
  final ExpenseManagementService? expenseManagementService;
  final ShoppingLifecycleService? shoppingService;
  final void Function(BuildContext context)? onOpenGeneralHome;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;
  final dynamic scheduleStore;
  final dynamic taskService;
  final ObligationService? obligationService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? SupabaseAuthRepository();
  late final HouseholdProfileRepository _profileRepository =
      widget.profileRepository ?? const SupabaseHouseholdProfileRepository();
  late final ExpenseManagementService _financeExpenseService =
      widget.expenseManagementService ??
          ExpenseManagementService(
            expenseRepository: const SupabaseExpenseRepository(),
            recurringRepository: const SupabaseRecurringExpenseRepository(),
          );
  late final bool _ownsAuthRepository = widget.authRepository == null;
  late final StreamSubscription<AuthState> _authSubscription;

  AuthState _authState = const UnauthenticatedAuthState();
  HouseholdProfile? _profile;
  bool _initializing = true;
  bool _loadingProfile = false;
  String? _profileError;
  bool _receivedAuthEvent = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = _authRepository.authStateChanges.listen(_onAuthState);
    _initialize();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    if (_ownsAuthRepository) {
      unawaited(_authRepository.dispose());
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final AuthState state = await _authRepository.initialize();
      if (!mounted) return;
      setState(() => _authState = state);
      if (!_receivedAuthEvent) {
        await _resolveAuthenticatedUser(state);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _profileError = 'تعذر بدء جلسة NUS الآن. حاول مرة أخرى.';
      });
    }
  }

  void _onAuthState(AuthState state) {
    if (!mounted) return;
    _receivedAuthEvent = true;
    setState(() {
      _authState = state;
      _profile = null;
      _profileError = null;
      _loadingProfile = state.isAuthenticated;
    });
    unawaited(_resolveAuthenticatedUser(state));
  }

  Future<void> _resolveAuthenticatedUser(AuthState state) async {
    if (!state.isAuthenticated) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _initializing = false;
        });
      }
      return;
    }

    final String? userId = state.session?.user.id;
    if (userId == null || userId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
          _initializing = false;
          _profileError = 'تعذر تحديد حساب المستخدم الحالي.';
        });
      }
      return;
    }

    try {
      final HouseholdProfile? profile = await _profileRepository.load(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingProfile = false;
        _initializing = false;
        _profileError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profile = null;
        _profileError = 'تعذر قراءة الملف المالي المحفوظ. لن نعتبر الإعداد مكتملًا قبل التأكد من البيانات.';
        _loadingProfile = false;
        _initializing = false;
      });
    }
  }

  Future<void> _retryProfile() async {
    if (_loadingProfile) return;
    setState(() => _loadingProfile = true);
    await _resolveAuthenticatedUser(_authState);
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || _loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authState.isAuthenticated) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: AuthPage(),
      );
    }

    final String userId = _authState.session!.user.id;
    if (_profileError != null) {
      return _ErrorView(message: _profileError!, onRetry: _retryProfile);
    }

    final HouseholdProfile? profile = _profile;
    if (profile == null || !const HouseholdProfileValidator().isValid(profile)) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: HouseholdOnboardingPage(
          userId: userId,
          repository: _profileRepository,
          initialProfile: profile,
          onCompleted: (HouseholdProfile saved) {
            if (mounted) setState(() => _profile = saved);
          },
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: NusFinancialHomePage(
        profile: profile,
        expenseManagementService: _financeExpenseService,
        onSignOut: () => _authRepository.signOut(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.cloud_off_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
