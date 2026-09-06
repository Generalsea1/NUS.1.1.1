import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'core/supabase_service.dart';
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
  bool isArabic = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUS',
      locale: isArabic ? const Locale('ar') : const Locale('en'),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3347A6)),
      ),
      home: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: HomePage(
          store: widget.store,
          medicationService: widget.medicationService,
          shoppingService: widget.shoppingService,
          expenseService: widget.expenseService,
          isArabic: isArabic,
          onToggleLanguage: () => setState(() => isArabic = !isArabic),
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
  });

  final ScheduleStore store;
  final MedicationLifecycleService? medicationService;
  final ShoppingLifecycleService? shoppingService;
  final ExpenseLifecycleService? expenseService;
  final bool isArabic;
  final VoidCallback onToggleLanguage;

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
        .take(8)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF18214B),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('N', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21,
            )),
          ),
          const SizedBox(width: 10),
          const Text('NUS', style: TextStyle(
            fontWeight: FontWeight.w900, letterSpacing: 1.2,
          )),
        ]),
        actions: [
          TextButton(
            onPressed: widget.onToggleLanguage,
            child: Text(t('العربية', 'English')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          children: [
            Text(t('Good day', 'أهلاً بيك'), style: TextStyle(
              color: Colors.grey.shade600, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 8),
            Text(t('What’s on your mind?', 'إيه اللي وراك؟'), style: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w900, height: 1.05,
            )),
            const SizedBox(height: 10),
            Text(
              t('Add a reminder and keep your day under control.',
                'ضيف تذكير وسيب يومك مترتّب قدامك.'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _showAddSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(t('Add reminder', 'إضافة تذكير'), style: const TextStyle(
                  fontWeight: FontWeight.w900,
                )),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AppointmentsPage(isArabic: widget.isArabic)),
              ),
              icon: const Icon(Icons.event_available_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(t('Appointments', 'المواعيد'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.medicationService == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MedicationsPage(
                          service: widget.medicationService!,
                          isArabic: widget.isArabic,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.medication_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(t('Medications', 'الأدوية'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.shoppingService == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShoppingPage(
                          service: widget.shoppingService!,
                          isArabic: widget.isArabic,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(t('Shopping', 'المشتريات'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.expenseService == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HouseholdExpenseManagerPage(
                          service: widget.expenseService!,
                          isArabic: widget.isArabic,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  t('Household Expense Manager', 'مصروفات مدير المنزل'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeader(title: t('Today', 'النهارده'), count: todays.length),
            const SizedBox(height: 12),
            if (todays.isEmpty)
              _EmptyCard(
                title: t('Nothing scheduled yet', 'لسه مفيش مواعيد'),
                subtitle: t('Add your first reminder and take it off your mind.',
                    'ضيف أول تذكير وخليه خارج دماغك.'),
              )
            else
              ...todays.map(_buildItemCard),
            const SizedBox(height: 24),
            _SectionHeader(title: t('Upcoming', 'القادم'), count: upcoming.length),
            const SizedBox(height: 12),
            if (upcoming.isEmpty)
              _EmptyCard(
                title: t('No upcoming reminders', 'مفيش تذكيرات جاية'),
                subtitle: t('Your next plans will appear here.',
                    'مواعيدك الجاية هتظهر هنا.'),
              )
            else
              ...upcoming.map(_buildItemCard),
          ],
        ),
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
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: IconButton.filledTonal(
            onPressed: () => widget.store.toggle(item),
            icon: Icon(item.completed ? Icons.check_rounded : Icons.event_available_rounded),
          ),
          title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('$date • $time'),
          trailing: item.completed
              ? const Icon(Icons.check_circle_rounded)
              : const Icon(Icons.chevron_left_rounded),
        ),
      ),
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final controller = TextEditingController();
    var date = DateTime.now().add(const Duration(hours: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) {
      controller.dispose();
      return;
    }
    date = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, date.hour, date.minute);
    final pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(date));
    if (pickedTime == null || !mounted) {
      controller.dispose();
      return;
    }
    date = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('New reminder', 'تذكير جديد'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: t('Title', 'عنوان التذكير'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submitReminder(sheetContext, controller, date),
              ),
              const SizedBox(height: 12),
              Text('${t('When', 'الموعد')}: ${widget.isArabic ? '${date.day}/${date.month}' : '${date.month}/${date.day}'} • ${TimeOfDay.fromDateTime(date).format(context)}'),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _submitReminder(sheetContext, controller, date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(t('Save reminder', 'حفظ التذكير')),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (added == true && mounted) setState(() {});
  }

  Future<void> _submitReminder(BuildContext context, TextEditingController controller, DateTime date) async {
    final title = controller.text.trim();
    if (title.isEmpty) return;
    await widget.store.add(title, date);
    if (context.mounted) Navigator.of(context).pop(true);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count'),
        ),
      ]);
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(height: 1.4)),
          ]),
        ),
      );
}