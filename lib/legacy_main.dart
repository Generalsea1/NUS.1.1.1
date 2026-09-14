import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/supabase_service.dart';
import 'notification_service.dart';
import 'features/appointments/presentation/appointments_page.dart';
import 'features/appointments/data/local_appointment_repository.dart';
import 'features/appointments/domain/appointment.dart';
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
  final LocalAppointmentRepository _appointmentRepository = LocalAppointmentRepository();
  List<Appointment> _appointments = <Appointment>[];

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
    _loadAppointments();
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

  Future<void> _loadAppointments() async {
    final appointments = await _appointmentRepository.list();
    if (!mounted) return;
    setState(() => _appointments = appointments);
  }

  Future<void> _openAppointments(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AppointmentsPage(isArabic: widget.isArabic),
    ));
    await _loadAppointments();
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
    final todayAppointments = _appointments
        .where((item) => DateUtils.isSameDay(item.startsAt, today) && item.status != AppointmentStatus.cancelled)
        .toList();
    final upcomingAppointments = _appointments
        .where((item) => item.status == AppointmentStatus.upcoming && item.startsAt.isAfter(now) && !DateUtils.isSameDay(item.startsAt, today))
        .take(6)
        .toList();
    final completedAppointments = _appointments
        .where((item) => item.status == AppointmentStatus.completed)
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
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'language',
                child: Text(t('العربية', 'English')),
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
            _dailyFocusCard(context, todays.length + todayAppointments.length + upcoming.length + upcomingAppointments.length),
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
            if (todayAppointments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(t('Today appointments', 'مواعيد النهارده'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...todayAppointments.map(_buildAppointmentCard),
            ],
            if (upcoming.isNotEmpty || upcomingAppointments.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader(t('Upcoming', 'اللي جاي'), upcoming.length + upcomingAppointments.length),
              const SizedBox(height: 10),
              ...upcoming.map(_buildItemCard),
              ...upcomingAppointments.map(_buildAppointmentCard),
            ],
            if (completedAppointments.isNotEmpty) ...[
              const SizedBox(height: 24),
              _sectionHeader(t('Completed appointments', 'مواعيد خلصت'), completedAppointments.length),
              const SizedBox(height: 10),
              ...completedAppointments.map(_buildAppointmentCard),
            ],
            const SizedBox(height: 24),
            Text(t('Your home tools', 'أدوات البيت'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            _toolGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
        boxShadow: const [
          BoxShadow(blurRadius: 28, offset: Offset(0, 12), color: Color(0x22000000)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary, size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text(
            t('A calmer day starts with NUS', 'يوم أهدى يبدأ مع NUS'),
            style: TextStyle(color: scheme.onPrimary, fontSize: 25, fontWeight: FontWeight.w900),
          )),
        ]),
        const SizedBox(height: 12),
        Text(
          t(
            'Keep reminders, appointments, shopping, and household tasks in one place.',
            'خلي التذكيرات والمواعيد والمشتريات ومهام البيت في مكان واحد.',
          ),
          style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9), height: 1.5),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _heroMetric(t('Today', 'النهارده'), '${widget.store.items.where((item) => DateUtils.isSameDay(item.dateTime, DateTime.now())).length}')),
          const SizedBox(width: 10),
          Expanded(child: _heroMetric(t('Upcoming', 'اللي جاي'), '${widget.store.items.where((item) => item.dateTime.isAfter(DateTime.now())).length}')),
        ]),
      ]),
    );
  }

  Widget _heroMetric(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _quickActions(BuildContext context) => Row(children: [
    Expanded(child: FilledButton.icon(
      onPressed: () => _openAppointments(context),
      icon: const Icon(Icons.event_available_rounded),
      label: Text(t('Appointment', 'ميعاد')),
    )),
    const SizedBox(width: 10),
    Expanded(child: OutlinedButton.icon(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add_task_rounded),
      label: Text(t('Reminder', 'تذكير')),
    )),
  ]);

  Widget _dailyFocusCard(BuildContext context, int count) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.center_focus_strong_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Daily focus', 'تركيز النهارده'), style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            count == 0
                ? t('Nothing urgent is scheduled.', 'مفيش حاجة مستعجلة متسجلة.')
                : t('$count item(s) need attention.', 'عندك $count حاجة محتاجة انتباه.'),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ])),
      ]),
    ),
  );

  Widget _sectionHeader(String title, int count) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w900)),
    ),
  ]);

  Widget _buildItemCard(ScheduleItem item) => Card(
    child: ListTile(
      leading: Checkbox(value: item.completed, onChanged: (_) => widget.store.toggle(item)),
      title: Text(item.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: item.completed ? TextDecoration.lineThrough : null)),
      subtitle: Text(MaterialLocalizations.of(context).formatFullDate(item.dateTime)),
      trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => widget.store.remove(item)),
    ),
  );

  Widget _buildAppointmentCard(Appointment appointment) => Card(
    child: ListTile(
      leading: const Icon(Icons.event_rounded),
      title: Text(appointment.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(MaterialLocalizations.of(context).formatShortDate(appointment.startsAt)),
      onTap: () => _openAppointments(context),
    ),
  );

  Widget _toolGrid(BuildContext context) {
    final tools = <_ToolItem>[
      _ToolItem(Icons.receipt_long_rounded, t('Expenses', 'مصروفات'), () {
        final service = widget.expenseService;
        if (service == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HouseholdExpenseManagerPage(service: service),
        ));
      }),
      _ToolItem(Icons.shopping_cart_checkout_rounded, t('Shopping', 'مشتريات'), () {
        final service = widget.shoppingService;
        if (service == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ShoppingPage(service: service),
        ));
      }),
      _ToolItem(Icons.medical_services_outlined, t('Medications', 'أدوية'), () {
        final service = widget.medicationService;
        if (service == null) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MedicationsPage(service: service),
        ));
      }),
      _ToolItem(Icons.event_note_rounded, t('Appointments', 'مواعيد'), () => _openAppointments(context)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.42,
      ),
      itemBuilder: (_, index) {
        final tool = tools[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: tool.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(tool.icon, size: 30, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(tool.label, style: const TextStyle(fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyCard(BuildContext context, String title, String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(children: [
        Icon(Icons.check_circle_outline_rounded, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        const SizedBox(height: 5),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    ),
  );

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(hours: 1));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(t('Add reminder', 'إضافة تذكير')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: t('Title', 'عنوان التذكير')),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(MaterialLocalizations.of(context).formatFullDate(selected)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: selected,
                );
                if (date == null) return;
                final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selected));
                if (time == null) return;
                setState(() => selected = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel', 'إلغاء'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Save', 'حفظ'))),
          ],
        ),
      ),
    );
    if (result == true) {
      await widget.store.add(controller.text, selected);
    }
    controller.dispose();
  }
}

class _ToolItem {
  const _ToolItem(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
