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
import '../../../legacy_main.dart' as legacy;
import '../../shopping/application/shopping_lifecycle_service.dart';
import '../../household/application/household_service.dart';
import '../../household/application/household_task_service.dart';
import '../../household/data/supabase_household_repository.dart';
import '../../household/data/supabase_household_task_repository.dart';
import '../../household/domain/household.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../finance/presentation/nus_financial_home_page.dart';
import '../application/household_profile_repository.dart';
import '../application/household_profile_validator.dart';
import '../data/supabase_household_profile_repository.dart';
import '../domain/household_profile.dart';
import '../../today/presentation/nus_unified_work_page.dart';
import 'auth_page.dart';
import 'household_onboarding_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authRepository, this.profileRepository, this.incomeRepository, this.expenseService, this.expenseManagementService, this.shoppingService, this.onOpenGeneralHome, this.onCreateReminder, this.scheduleStore, this.taskService, this.obligationService});

  final AuthRepository? authRepository;
  final HouseholdProfileRepository? profileRepository;
  final IncomeSourceRepository? incomeRepository;
  final ExpenseLifecycleService? expenseService;
  final ExpenseManagementService? expenseManagementService;
  final ShoppingLifecycleService? shoppingService;
  final void Function(BuildContext context)? onOpenGeneralHome;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;
  final legacy.ScheduleStore? scheduleStore;
  final HouseholdTaskService? taskService;
  final ObligationService? obligationService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _authRepository = widget.authRepository ?? SupabaseAuthRepository();
  late final HouseholdProfileRepository _profileRepository = widget.profileRepository ?? const SupabaseHouseholdProfileRepository();
  late final IncomeSourceRepository _incomeRepository = widget.incomeRepository ?? const SupabaseIncomeSourceRepository();
  late final HouseholdTaskService _taskService = widget.taskService ?? HouseholdTaskService(repository: const SupabaseHouseholdTaskRepository());
  late final ObligationService _obligationService = widget.obligationService ?? const ObligationService(repository: SupabaseObligationRepository());
  late final ExpenseManagementService _financeExpenseService = widget.expenseManagementService ?? ExpenseManagementService(expenseRepository: const SupabaseExpenseRepository(), recurringRepository: const SupabaseRecurringExpenseRepository());
  late final bool _ownsAuthRepository = widget.authRepository == null;
  late final StreamSubscription<AuthState> _authSubscription;

  AuthState _authState = const UnauthenticatedAuthState();
  HouseholdProfile? _profile;
  Household? _household;
  ShoppingLifecycleService? _householdShoppingService;
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
    if (_ownsAuthRepository) unawaited(_authRepository.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final state = await _authRepository.initialize();
      if (!mounted) return;
      setState(() => _authState = state);
      if (!_receivedAuthEvent) await _resolveAuthenticatedUser(state);
    } catch (_) {
      if (!mounted) return;
      setState(() { _initializing = false; _profileError = _readableError(); });
    }
  }

  void _onAuthState(AuthState state) {
    if (!mounted) return;
    _receivedAuthEvent = true;
    setState(() {
      _authState = state;
      _profile = null;
      _household = null;
      _householdShoppingService = null;
      _profileError = null;
      _loadingProfile = state.isAuthenticated;
    });
    unawaited(_resolveAuthenticatedUser(state));
  }

  Future<void> _resolveAuthenticatedUser(AuthState state) async {
    if (!state.isAuthenticated) {
      if (mounted) setState(() { _loadingProfile = false; _initializing = false; });
      return;
    }
    final userId = state.session?.user.id;
    if (userId == null || userId.trim().isEmpty) {
      if (mounted) setState(() { _loadingProfile = false; _initializing = false; _profileError = 'تعذر تحديد حساب المستخدم الحالي.'; });
      return;
    }
    try {
      final profile = await _profileRepository.load(userId);
      if (!mounted) return;
      Household? household;
      ShoppingLifecycleService? householdShoppingService;
      if (SupabaseService.client != null) {
        try {
          household = await HouseholdService(repository: const SupabaseHouseholdRepository()).getOrCreateForUser(userId: userId);
          householdShoppingService = ShoppingLifecycleService(repository: SupabaseHouseholdShoppingRepository(householdId: household.id));
        } catch (_) {}
      }
      setState(() { _profile = profile; _household = household; _householdShoppingService = householdShoppingService; _profileError = null; _loadingProfile = false; _initializing = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _profile = null; _profileError = 'تعذر قراءة الملف المالي المحفوظ. لن نعتبر الإعداد مكتملًا قبل التأكد من البيانات.'; _loadingProfile = false; _initializing = false; });
    }
  }

  String _readableError() => 'تعذر بدء جلسة NUS الآن. راجع إعدادات الاتصال ثم حاول مرة أخرى.';

  Future<void> _retryProfile() async {
    if (_loadingProfile) return;
    setState(() => _loadingProfile = true);
    await _resolveAuthenticatedUser(_authState);
  }

  void _openUnifiedWork(BuildContext context, String userId) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => NusUnifiedWorkPage(userId: userId, householdId: _household?.id, scheduleStore: widget.scheduleStore ?? legacy.ScheduleStore(), taskService: _taskService, obligationService: _obligationService)));
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing || _loadingProfile) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_authState.isAuthenticated) return const Directionality(textDirection: TextDirection.rtl, child: AuthPage());
    final userId = _authState.session!.user.id;
    if (_profileError != null) return _ErrorView(message: _profileError!, onRetry: _retryProfile);
    final profile = _profile;
    if (profile == null || !const HouseholdProfileValidator().isValid(profile)) {
      return Directionality(textDirection: TextDirection.rtl, child: HouseholdOnboardingPage(userId: userId, repository: _profileRepository, initialProfile: profile, onCompleted: (saved) { if (mounted) setState(() => _profile = saved); }));
    }
    return Directionality(textDirection: TextDirection.rtl, child: NusFinancialHomePage(profile: profile, expenseManagementService: _financeExpenseService, onSignOut: () => _authRepository.signOut()));
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 48), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))]))))));
}
