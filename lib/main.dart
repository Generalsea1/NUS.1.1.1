import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/supabase_service.dart';
import 'notification_service.dart';
import 'features/expenses/application/expense_lifecycle_service.dart';
import 'features/expenses/application/expense_management_service.dart';
import 'features/expenses/data/supabase_expense_repository.dart';
import 'features/expenses/data/supabase_recurring_expense_repository.dart';
import 'features/medications/application/medication_lifecycle_service.dart';
import 'features/medications/application/medication_reminder_coordinator.dart';
import 'features/medications/data/local_medication_repository.dart';
import 'features/medications/data/medication_reminder_adapter.dart';
import 'features/shopping/application/shopping_lifecycle_service.dart';
import 'features/shopping/data/local_shopping_repository.dart';
import 'features/onboarding/presentation/auth_gate.dart';
import 'legacy_main.dart' as legacy;

export 'legacy_main.dart' show HomePage, NosApp, ScheduleItem, ScheduleStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  final notifications = NotificationService();
  await notifications.initialize();
  final store = legacy.ScheduleStore(notifications: notifications);
  await store.load();
  await store.reschedulePending();

  final medicationService = MedicationLifecycleService(
    repository: LocalMedicationRepository(),
    reminders: MedicationReminderCoordinator(
      MedicationReminderAdapter(notifications),
    ),
  );
  final shoppingService = ShoppingLifecycleService(
    repository: LocalShoppingRepository(),
  );
  final expenseService = ExpenseLifecycleService(
    repository: LocalExpenseRepository(),
  );
  final expenseManagementService = ExpenseManagementService(
    expenseRepository: const SupabaseExpenseRepository(),
    recurringRepository: const SupabaseRecurringExpenseRepository(),
  );

  runApp(
    Nus2App(
      store: store,
      medicationService: medicationService,
      shoppingService: shoppingService,
      expenseService: expenseService,
      expenseManagementService: expenseManagementService,
    ),
  );
}

class Nus2App extends StatefulWidget {
  const Nus2App({
    super.key,
    required this.store,
    required this.medicationService,
    required this.shoppingService,
    required this.expenseService,
    required this.expenseManagementService,
  });

  final legacy.ScheduleStore store;
  final MedicationLifecycleService medicationService;
  final ShoppingLifecycleService shoppingService;
  final ExpenseLifecycleService expenseService;
  final ExpenseManagementService expenseManagementService;

  @override
  State<Nus2App> createState() => _Nus2AppState();
}

class _Nus2AppState extends State<Nus2App> {
  static const _themeKey = 'nus.appearance.theme_mode.v1';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = switch (prefs.getString(_themeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _toggleTheme() async {
    final next = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() => _themeMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      next == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          brightness: brightness,
        ),
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? const Color(0xFF0B0D14)
            : const Color(0xFFF6F7FB),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: brightness == Brightness.dark
              ? const Color(0xFF151925)
              : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUS',
      locale: const Locale('ar'),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: AuthGate(
        expenseService: widget.expenseService,
        expenseManagementService: widget.expenseManagementService,
        onOpenGeneralHome: (context) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: legacy.HomePage(
                  store: widget.store,
                  medicationService: widget.medicationService,
                  shoppingService: widget.shoppingService,
                  expenseService: widget.expenseService,
                  isArabic: true,
                  onToggleLanguage: () {},
                  themeMode: _themeMode,
                  onToggleTheme: _toggleTheme,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
