import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'features/appointments/presentation/appointments_page.dart';
import 'features/expenses/application/expense_lifecycle_service.dart';
import 'features/expenses/presentation/household_expense_manager_page.dart';
import 'features/medications/application/medication_lifecycle_service.dart';
import 'features/medications/application/medication_reminder_coordinator.dart';
import 'features/medications/data/local_medication_repository.dart';
import 'features/medications/data/medication_reminder_adapter.dart';
import 'features/medications/presentation/medications_page.dart';
import 'features/shopping/application/shopping_lifecycle_service.dart';
import 'features/shopping/data/local_shopping_repository.dart';
import 'features/shopping/presentation/shopping_page.dart';
import 'features/ai/presentation/ai_settings_page.dart';
import 'features/ai/presentation/ai_history_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = NotificationService();
  await notifications.initialize();

  final store = ScheduleStore(notifications: notifications);
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

  runApp(NosApp(
    store: store,
    medicationService: medicationService,
    shoppingService: shoppingService,
    expenseService: expenseService,
  ));
}

class NosApp extends StatefulWidget {
  const NosApp({
    super.key,
    required this.store,
    this.medicationService,
    this.shoppingService,
    this.expenseService,
  });

  final ScheduleStore store;
  final MedicationLifecycleService? medicationService;
  final ShoppingLifecycleService? shoppingService;
  final ExpenseLifecycleService? expenseService;

  @override
  State<NosApp> createState() => _NosAppState();
}

class _NosAppState extends State<NosApp> {
  static const _darkModeKey = 'nus.settings.dark_mode.v1';
  static const _languageKey = 'nus.settings.arabic.v1';

  bool isArabic = true;
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      isArabic = prefs.getBool(_languageKey) ?? true;
    });
  }

  Future<void> _toggleDarkMode() async {
    final next = !isDarkMode;
    setState(() => isDarkMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, next);
  }

  Future<void> _toggleLanguage() async {
    final next = !isArabic;
    setState(() => isArabic = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageKey, next);
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5CE2),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF0B1020) : const Color(0xFFF5F7FB),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: dark ? Colors.white : const Color(0xFF14182B),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF141A2E) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF151C31) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUS',
      locale: isArabic ? const Locale('ar') : const Locale('en'),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomePage(
          store: widget.store,
          medicationService: widget.medicationService,
          shoppingService: widget.shoppingService,
          expenseService: widget.expenseService,
          isArabic: isArabic,
          isDarkMode: isDarkMode,
          onToggleLanguage: _toggleLanguage,
          onToggleDarkMode: _toggleDarkMode,
        ),
      ),
    );
  }
}

class ScheduleItem {
  ScheduleItem({
    required this.id,
    required this.title,
    required this.dateTime,
    this.completed = false,
  });

  final String id;
  final String title;
  final DateTime dateTime;
  bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'completed': completed,
      };

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
        id: json['id'] as String,
        title: json['title'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        completed: json['completed'] as bool? ?? false,
      );
}

class ScheduleStore extends ChangeNotifier {
  ScheduleStore({this.notifications});

  static const _storageKey = 'nos.schedule.v1';
  final List<ScheduleItem> items = [];
  final ReminderScheduler? notifications;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    items
      ..clear()
      ..addAll(decoded.map((entry) => ScheduleItem.fromJson(
            Map<String, dynamic>.from(entry as Map),
          )))
      ..sort(_compareItems);
  }

  Future<void> reschedulePending() async {
    final service = notifications;
    if (service == null) return;
    for (final item in items) {
      if (!item.completed && item.dateTime.isAfter(DateTime.now())) {
        await service.scheduleReminder(
          id: item.id,
          title: item.title,
          dateTime: item.dateTime,
        );
      }
    }
  }

  Future<void> add(String title, DateTime dateTime) async {
    final clean = title.trim();
    if (clean.isEmpty || dateTime.isBefore(DateTime.now())) return;

    final item = ScheduleItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: clean,
      dateTime: dateTime,
    );
    items.add(item);
    items.sort(_compareItems);
    await _save();

    final service = notifications;
    if (service != null) {
      if (service is NotificationService) {
        await service.requestPermission();
        await service.requestExactAlarmPermission();
      }
      await service.scheduleReminder(
        id: item.id,
        title: item.title,
        dateTime: item.dateTime,
      );
    }
    notifyListeners();
  }

  Future<void> toggle(ScheduleItem item) async {
    item.completed = !item.completed;
    await _save();

    final service = notifications;
    if (service != null) {
      if (item.completed) {
        await service.cancelReminder(item.id);
      } else if (item.dateTime.isAfter(DateTime.now())) {
        if (service is NotificationService) {
          await service.requestPermission();
          await service.requestExactAlarmPermission();
        }
        await service.scheduleReminder(
          id: item.id,
          title: item.title,
          dateTime: item.dateTime,
        );
      }
    }
    notifyListeners();
  }

  Future<void> remove(ScheduleItem item) async {
    items.removeWhere((candidate) => candidate.id == item.id);
    await _save();
    await notifications?.cancelReminder(item.id);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  static int _compareItems(ScheduleItem a, ScheduleItem b) =>
      a.dateTime.compareTo(b.dateTime);
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    this.medicationService,
    this.shoppingService,
    this.expenseService,
    required this.isArabic,
    required this.isDarkMode,
    required this.onToggleLanguage,
    required this.onToggleDarkMode,
  });

  final ScheduleStore store;
  final MedicationLifecycleService? medicationService;
  final ShoppingLifecycleService? shoppingService;
  final ExpenseLifecycleService? expenseService;
  final bool isArabic;
  final bool isDarkMode;
  final Future<void> Function() onToggleLanguage;
  final Future<void> Function() onToggleDarkMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_refresh);
      widget.store.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _openFeature(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final todays = widget.store.items
        .where((item) => DateUtils.isSameDay(item.dateTime, today))
        .toList();
    final upcoming = widget.store.items
        .where((item) => item.dateTime.isAfter(now) && !DateUtils.isSameDay(item.dateTime, today))
        .take(6)
        .toList();
    final completedToday = todays.where((item) => item.completed).length;
    final dark = widget.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const _BrandMark(),
        actions: [
          IconButton(
            tooltip: t('AI & Google account', 'الذكاء الاصطناعي وحساب Google'),
            onPressed: () => _openFeature(AiSettingsPage(isArabic: widget.isArabic)),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          IconButton(
            tooltip: t('AI history', 'سجل الذكاء الاصطناعي'),
            onPressed: () => _openFeature(AiHistoryPage(isArabic: widget.isArabic)),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: t('Dark mode', 'الوضع الداكن'),
            onPressed: widget.onToggleDarkMode,
            icon: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: t('Settings', 'الإعدادات'),
            onSelected: (value) async {
              if (value == 'language') await widget.onToggleLanguage();
              if (value == 'dark') await widget.onToggleDarkMode();
              if (value == 'ai') await _openFeature(AiSettingsPage(isArabic: widget.isArabic));
              if (value == 'history') await _openFeature(AiHistoryPage(isArabic: widget.isArabic));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'language', child: Text(t('العربية', 'English'))),
              PopupMenuItem(value: 'dark', child: Text(t('Dark mode', 'الوضع الداكن'))),
              PopupMenuItem(value: 'ai', child: Text(t('Google AI account', 'حساب Google للذكاء الاصطناعي'))),
              PopupMenuItem(value: 'history', child: Text(t('AI history', 'سجل الذكاء الاصطناعي'))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _HeroDashboard(
                    isArabic: widget.isArabic,
                    dark: dark,
                    onAi: () => _openFeature(AiSettingsPage(isArabic: widget.isArabic)),
                  ),
                  const SizedBox(height: 20),
                  Text(t('لوحة التحكم', 'Control center'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  _QuickGrid(
                    isArabic: widget.isArabic,
                    onAppointments: () => _openFeature(AppointmentsPage(isArabic: widget.isArabic)),
                    onMedications: widget.medicationService == null
                        ? null
                        : () => _openFeature(MedicationsPage(service: widget.medicationService!, isArabic: widget.isArabic)),
                    onShopping: widget.shoppingService == null
                        ? null
                        : () => _openFeature(ShoppingPage(service: widget.shoppingService!, isArabic: widget.isArabic)),
                    onExpenses: widget.expenseService == null
                        ? null
                        : () => _openFeature(HouseholdExpenseManagerPage(service: widget.expenseService!, isArabic: widget.isArabic)),
                  ),
                  const SizedBox(height: 24),
                  _TodaySummary(
                    total: todays.length,
                    completed: completedToday,
                    isArabic: widget.isArabic,
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: t('اليوم', 'Today'),
                    count: todays.length,
                    icon: Icons.today_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (todays.isEmpty)
                    _EmptyState(
                      icon: Icons.event_note_rounded,
                      title: t('يومك لسه فاضي', 'Your day is clear'),
                      subtitle: t('أضف أول تذكير وخلي NUS يرتّب يومك.', 'Add a reminder and let NUS keep your day organized.'),
                      action: _showAddSheet,
                      actionLabel: t('إضافة تذكير', 'Add reminder'),
                    )
                  else
                    ...todays.map(_buildItemCard),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: t('القادم', 'Upcoming'),
                    count: upcoming.length,
                    icon: Icons.upcoming_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (upcoming.isEmpty)
                    _EmptyState(
                      icon: Icons.auto_awesome_rounded,
                      title: t('لا يوجد شيء معلّق', 'Nothing waiting'),
                      subtitle: t('مواعيدك القادمة ستظهر هنا تلقائياً.', 'Your next plans will appear here automatically.'),
                      action: _showAddSheet,
                      actionLabel: t('خطّط لموعد', 'Plan a reminder'),
                    )
                  else
                    ...upcoming.map(_buildItemCard),
                ]),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('إضافة', 'Add')),
      ),
    );
  }

  Widget _buildItemCard(ScheduleItem item) {
    final time = TimeOfDay.fromDateTime(item.dateTime).format(context);
    final date = widget.isArabic
        ? '${item.dateTime.day}/${item.dateTime.month}'
        : '${item.dateTime.month}/${item.dateTime.day}';

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await widget.store.remove(item);
        return true;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          leading: IconButton.filledTonal(
            onPressed: () => widget.store.toggle(item),
            icon: Icon(item.completed ? Icons.check_rounded : Icons.event_available_rounded),
          ),
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              decoration: item.completed ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('$date • $time'),
          ),
          trailing: Icon(
            item.completed ? Icons.task_alt_rounded : Icons.chevron_left_rounded,
            color: item.completed ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final controller = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(minutes: 30));
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t('تذكير جديد', 'New reminder'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: t('اكتب التذكير', 'Reminder title'),
                      hintText: t('مثلاً: دفع فاتورة الكهرباء', 'Example: Pay the electricity bill'),
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(t('التاريخ والوقت', 'Date & time')),
                      subtitle: Text(MaterialLocalizations.of(context).formatFullDate(selected)),
                      trailing: Text(TimeOfDay.fromDateTime(selected).format(context)),
                      onTap: () async {
                        final day = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                          initialDate: selected,
                        );
                        if (!context.mounted) return;
                        if (day == null) return;
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selected),
                        );
                        if (!context.mounted) return;
                        if (time == null) return;
                        setSheetState(() {
                          selected = DateTime(day.year, day.month, day.day, time.hour, time.minute);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      if (controller.text.trim().isEmpty) return;
                      Navigator.of(sheetContext).pop(selected);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: Text(t('حفظ التذكير', 'Save reminder')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      controller.dispose();
      return;
    }
    if (result != null && controller.text.trim().isNotEmpty) {
      await widget.store.add(controller.text, result);
    }
    controller.dispose();
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'NUS',
      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1.8),
    );
  }
}

class _HeroDashboard extends StatelessWidget {
  const _HeroDashboard({required this.isArabic, required this.dark, required this.onAi});

  final bool isArabic;
  final bool dark;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.alphaBlend(Colors.black.withValues(alpha: .18), scheme.primary),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: dark ? .16 : .22),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white),
              ),
              const Spacer(),
              _Pill(
                icon: Icons.shield_rounded,
                text: isArabic ? 'خصوصيتك أولاً' : 'Privacy first',
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            isArabic ? 'NUS يدير يومك من مكان واحد' : 'NUS keeps your life in one place',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
          ),
          const SizedBox(height: 9),
          Text(
            isArabic
                ? 'مواعيدك، مشترياتك، أدويتك، ومصروفات مدير المنزل — كلها مرتبطة بتجربة واحدة واضحة.'
                : 'Appointments, shopping, medication and household planning — connected in one clear experience.',
            style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAi,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: scheme.primary,
              minimumSize: const Size(0, 50),
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(isArabic ? 'افتح مساعد NUS الذكي' : 'Open NUS AI assistant'),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid({
    required this.isArabic,
    required this.onAppointments,
    required this.onMedications,
    required this.onShopping,
    required this.onExpenses,
  });

  final bool isArabic;
  final VoidCallback onAppointments;
  final VoidCallback? onMedications;
  final VoidCallback? onShopping;
  final VoidCallback? onExpenses;

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickAction(Icons.event_available_rounded, isArabic ? 'المواعيد' : 'Appointments', isArabic ? 'رتّب مواعيدك' : 'Stay ahead', onAppointments),
      _QuickAction(Icons.medication_rounded, isArabic ? 'الأدوية' : 'Medications', isArabic ? 'التزم بمواعيدك' : 'Never miss a dose', onMedications),
      _QuickAction(Icons.shopping_bag_rounded, isArabic ? 'المشتريات' : 'Shopping', isArabic ? 'قائمة أذكى' : 'Smarter shopping', onShopping),
      _QuickAction(Icons.account_balance_wallet_rounded, isArabic ? 'مصروفات مدير المنزل' : 'Household manager', isArabic ? 'خطّط بذكاء' : 'Plan intelligently', onExpenses),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemBuilder: (_, index) => _QuickActionCard(action: items[index]),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.icon, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: action.onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(action.icon, color: scheme.onPrimaryContainer),
            ),
            const Spacer(),
            Text(action.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(action.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.total, required this.completed, required this.isArabic});

  final int total;
  final int completed;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: progress, strokeWidth: 7),
                  Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isArabic ? 'إيقاع يومك' : 'Today at a glance', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(
                    isArabic
                        ? total == 0 ? 'ابدأ بإضافة أول مهمة أو موعد.' : '$completed من $total منجزين اليوم.'
                        : total == 0 ? 'Add your first task or appointment.' : '$completed of $total completed today.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.insights_rounded, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count, required this.icon});

  final String title;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onPrimaryContainer)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title, required this.subtitle, required this.action, required this.actionLabel});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 42, color: scheme.primary),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: action, icon: const Icon(Icons.add_rounded), label: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
