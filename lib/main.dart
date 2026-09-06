import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/supabase_service.dart';
import 'notification_service.dart';
import 'features/appointments/presentation/appointments_page.dart';
import 'features/ai/presentation/ai_hub_page.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
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
  static const _themeKey = 'nus.appearance.theme_mode.v1';

  bool isArabic = true;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadAppearance();
  }

  Future<void> _loadAppearance() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeKey);
    final mode = switch (raw) {
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
    await prefs.setString(_themeKey, next == ThemeMode.dark ? 'dark' : 'light');
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7986CB),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B0D14),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF151925),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF151925),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
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
      themeMode: _themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomePage(
          store: widget.store,
          medicationService: widget.medicationService,
          shoppingService: widget.shoppingService,
          expenseService: widget.expenseService,
          isArabic: isArabic,
          themeMode: _themeMode,
          onToggleLanguage: () => setState(() => isArabic = !isArabic),
          onToggleTheme: _toggleTheme,
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
    required this.onToggleLanguage,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ScheduleStore store;
  final MedicationLifecycleService? medicationService;
  final ShoppingLifecycleService? shoppingService;
  final ExpenseLifecycleService? expenseService;
  final bool isArabic;
  final VoidCallback onToggleLanguage;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final todays = widget.store.items
        .where((item) => DateUtils.isSameDay(item.dateTime, today))
        .toList();
    final upcoming = widget.store.items
        .where((item) => item.dateTime.isAfter(now) &&
            !DateUtils.isSameDay(item.dateTime, today))
        .take(6)
        .toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF303F9F), Color(0xFF7E57C2)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'NUS',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.themeMode == ThemeMode.dark
                ? t('Light mode', 'الوضع الفاتح')
                : t('Dark mode', 'الوضع الداكن'),
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: t('More', 'المزيد'),
            onSelected: (value) {
              if (value == 'language') widget.onToggleLanguage();
              if (value == 'ai') {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AiHubPage(),
                ));
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'language',
                child: Text(t('العربية', 'English')),
              ),
              PopupMenuItem(
                value: 'ai',
                child: Text(t('AI Center', 'مركز الذكاء الاصطناعي')),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
          children: [
            _heroCard(context),
            const SizedBox(height: 16),
            _quickActions(context),
            const SizedBox(height: 16),
            _dailyFocusCard(context, todays.length + upcoming.length),
            const SizedBox(height: 24),
            _sectionHeader(t('Today', 'النهارده'), todays.length),
            const SizedBox(height: 10),
            if (todays.isEmpty)
              _emptyCard(
                context,
                t('Nothing scheduled yet', 'لسه مفيش مواعيد'),
                t(
                  'Add your first reminder and keep your day organized.',
                  'ضيف أول تذكير وخلي يومك مترتّب من بدري.',
                ),
              )
            else
              ...todays.map(_buildItemCard),
            const SizedBox(height: 22),
            _sectionHeader(t('Upcoming', 'القادم'), upcoming.length),
            const SizedBox(height: 10),
            if (upcoming.isEmpty)
              _emptyCard(
                context,
                t('No upcoming reminders', 'مفيش تذكيرات جاية'),
                t(
                  'Your next plans will appear here.',
                  'مواعيدك الجاية هتظهر هنا.',
                ),
              )
            else
              ...upcoming.map(_buildItemCard),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primaryContainer],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    t('SMART LIFE MANAGER', 'مدير حياتك الذكي'),
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              t('Take control of your day.', 'خلّي يومك تحت السيطرة.'),
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'NUS brings reminders, family life, shopping and household spending into one intelligent home base.',
                'NUS بيجمع التذكيرات والبيت والمشتريات ومصروفات مدير المنزل في مكان واحد ذكي.',
              ),
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: .82),
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              ),
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                t('Add reminder', 'إضافة تذكير'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final actions = [
      (
        Icons.account_balance_wallet_rounded,
        t('Household Budget', 'ميزانية البيت'),
        () => widget.expenseService == null
            ? null
            : Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HouseholdExpenseManagerPage(
                  service: widget.expenseService!,
                  isArabic: widget.isArabic,
                ),
              )),
      ),
      (
        Icons.shopping_bag_outlined,
        t('Shopping', 'المشتريات'),
        () => widget.shoppingService == null
            ? null
            : Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ShoppingPage(
                  service: widget.shoppingService!,
                  isArabic: widget.isArabic,
                ),
              )),
      ),
      (
        Icons.medication_outlined,
        t('Medications', 'الأدوية'),
        () => widget.medicationService == null
            ? null
            : Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => MedicationsPage(
                  service: widget.medicationService!,
                  isArabic: widget.isArabic,
                ),
              )),
      ),
      (
        Icons.event_available_outlined,
        t('Appointments', 'المواعيد'),
        () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AppointmentsPage(isArabic: widget.isArabic),
            )),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 106,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: actions.length,
      itemBuilder: (_, index) {
        final action = actions[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: action.$3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(action.$1),
                  ),
                  const Spacer(),
                  Text(
                    action.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dailyFocusCard(BuildContext context, int count) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.track_changes_rounded, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('Today at a glance', 'ملخص يومك'),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    count == 0
                        ? t('Nothing pending. You are clear.', 'مفيش حاجة متعلقة. يومك هادي.')
                        : t('$count plan(s) around you.', 'عندك $count مهمة/ميعاد حوالين يومك.'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      );

  Widget _emptyCard(BuildContext context, String title, String subtitle) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check_circle_outline_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildItemCard(ScheduleItem item) {
    final time = TimeOfDay.fromDateTime(item.dateTime).format(context);
    final date = widget.isArabic
        ? '${item.dateTime.day}/${item.dateTime.month}'
        : '${item.dateTime.month}/${item.dateTime.day}';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await widget.store.remove(item);
          return true;
        },
        background: Container(
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: Icon(Icons.delete_outline, color: scheme.onError),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          subtitle: Text('$date  •  $time'),
          trailing: IconButton(
            onPressed: () => widget.store.remove(item),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    var title = '';
    var selected = DateTime.now().add(const Duration(minutes: 30));

    final reminder = await showModalBottomSheet<({String title, DateTime dateTime})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('New reminder', 'تذكير جديد'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (value) => title = value,
                decoration: InputDecoration(
                  labelText: t('What do you need to remember?', 'إيه اللي محتاج تفتكره؟'),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateUtils.dateOnly(DateTime.now()),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                          initialDate: selected,
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selected = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              selected.hour,
                              selected.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text('${selected.day}/${selected.month}/${selected.year}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selected),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selected = DateTime(
                              selected.year,
                              selected.month,
                              selected.day,
                              picked.hour,
                              picked.minute,
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(TimeOfDay.fromDateTime(selected).format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final cleanTitle = title.trim();
                  final reminderDate = selected;
                  if (cleanTitle.isEmpty || !reminderDate.isAfter(DateTime.now())) return;
                  Navigator.of(context).pop((
                    title: cleanTitle,
                    dateTime: reminderDate,
                  ));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(t('Save reminder', 'احفظ التذكير')),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('Cancel', 'إلغاء')),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || reminder == null) return;
    await widget.store.add(reminder.title, reminder.dateTime);
  }
}
