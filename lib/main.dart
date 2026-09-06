import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'features/appointments/presentation/appointments_page.dart';
import 'features/expenses/application/expense_lifecycle_service.dart';
import 'features/expenses/data/local_expense_repository.dart';
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

  int _compareItems(ScheduleItem a, ScheduleItem b) =>
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
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _addSchedule() async {
    await widget.store.add(_titleController.text, _selectedDate);
    if (!mounted) return;
    _titleController.clear();
    setState(() {});
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _selectedDate,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;
    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final arabic = widget.isArabic;
    return Scaffold(
      appBar: AppBar(
        title: Text(arabic ? 'NUS' : 'NUS'),
        actions: [
          IconButton(
            tooltip: arabic ? 'English' : 'العربية',
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.language),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                arabic
                    ? 'نظّم يومك، وتابع التزاماتك، وخلي التنبيهات تشتغل تلقائيًا.'
                    : 'Organize your day, track commitments, and let reminders work automatically.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: arabic ? 'إضافة تذكير' : 'Add reminder',
              ),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: arabic ? 'اسم المهمة' : 'Task title',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(arabic ? 'موعد التذكير' : 'Reminder time'),
                subtitle: Text(_selectedDate.toLocal().toString()),
                trailing: const Icon(Icons.schedule),
                onTap: _pickDateTime,
              ),
              FilledButton.icon(
                onPressed: _addSchedule,
                icon: const Icon(Icons.add_alert),
                label: Text(arabic ? 'إضافة التذكير' : 'Add reminder'),
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: arabic ? 'المواعيد' : 'Appointments'),
              FilledButton.tonalIcon(
                onPressed: widget.medicationService == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MedicationsPage(
                              service: widget.medicationService!,
                            ),
                          ),
                        ),
                icon: const Icon(Icons.medication_outlined),
                label: Text(arabic ? 'الأدوية والتذكيرات' : 'Medications & reminders'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.shoppingService == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShoppingPage(
                              service: widget.shoppingService!,
                            ),
                          ),
                        ),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: Text(arabic ? 'المشتريات' : 'Shopping'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.expenseService == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HouseholdExpenseManagerPage(
                              service: widget.expenseService!,
                            ),
                          ),
                        ),
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(
                  arabic ? 'مصروفات مدير المنزل' : 'Household Expense Manager',
                ),
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: arabic ? 'التذكيرات' : 'Reminders'),
              if (widget.store.items.isEmpty)
                _EmptyCard(
                  text: arabic ? 'لا توجد تذكيرات بعد.' : 'No reminders yet.',
                )
              else
                ...widget.store.items.map(
                  (item) => Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: item.completed,
                        onChanged: (_) => widget.store.toggle(item),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          decoration: item.completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(item.dateTime.toLocal().toString()),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => widget.store.remove(item),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _SectionHeader(
                title: arabic ? 'المواعيد الطبية' : 'Medical appointments',
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AppointmentsPage(store: widget.store),
                  ),
                ),
                icon: const Icon(Icons.event_available_outlined),
                label: Text(arabic ? 'فتح المواعيد' : 'Open appointments'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}
