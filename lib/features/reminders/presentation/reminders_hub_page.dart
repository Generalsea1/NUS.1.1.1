import 'package:flutter/material.dart';

import '../../../legacy_main.dart';
import '../../appointments/data/local_appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointments_page.dart';
import '../../medications/application/medication_lifecycle_service.dart';
import '../../medications/presentation/medications_page.dart';

class NusHomeShell extends StatefulWidget {
  const NusHomeShell({
    super.key,
    required this.profile,
    required this.expenseManagementService,
    required this.scheduleStore,
    required this.medicationService,
    required this.onSignOut,
  });

  final dynamic profile;
  final dynamic expenseManagementService;
  final ScheduleStore scheduleStore;
  final MedicationLifecycleService medicationService;
  final VoidCallback onSignOut;

  @override
  State<NusHomeShell> createState() => _NusHomeShellState();
}

class _NusHomeShellState extends State<NusHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          NusFinancialHomePage(
            profile: widget.profile,
            expenseManagementService: widget.expenseManagementService,
            onSignOut: widget.onSignOut,
          ),
          RemindersHubPage(
            scheduleStore: widget.scheduleStore,
            medicationService: widget.medicationService,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'البيت',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_active_rounded),
            label: 'متنساش مواعيدك',
          ),
        ],
      ),
    );
  }
}

class RemindersHubPage extends StatefulWidget {
  const RemindersHubPage({
    super.key,
    required this.scheduleStore,
    required this.medicationService,
  });

  final ScheduleStore scheduleStore;
  final MedicationLifecycleService medicationService;

  @override
  State<RemindersHubPage> createState() => _RemindersHubPageState();
}

class _RemindersHubPageState extends State<RemindersHubPage> {
  final LocalAppointmentRepository _appointments = LocalAppointmentRepository();
  List<Appointment> _appointmentItems = const <Appointment>[];
  int _medicationCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.scheduleStore.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    widget.scheduleStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait(<Future<Object>>[
        _appointments.list(),
        widget.medicationService.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _appointmentItems = results[0] as List<Appointment>;
        _medicationCount = (results[1] as List).length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openAppointments() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AppointmentsPage(isArabic: true)),
    );
    await _load();
  }

  Future<void> _openMedications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MedicationsPage(service: widget.medicationService, isArabic: true),
      ),
    );
    await _load();
  }

  Future<void> _addReminder() async {
    final TextEditingController controller = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(minutes: 30));
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تذكير جديد', textAlign: TextAlign.right),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textDirection: TextDirection.rtl,
                    decoration: const InputDecoration(
                      labelText: 'هفكّر في إيه؟',
                      hintText: 'مثال: دفع فاتورة الكهرباء',
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded),
                    title: const Text('التاريخ'),
                    subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setDialogState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          selectedDate.hour,
                          selectedDate.minute,
                        );
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('الوقت'),
                    subtitle: Text(TimeOfDay.fromDateTime(selectedDate).format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (picked == null) return;
                      setDialogState(() {
                        selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('حفظ التذكير'),
                ),
              ],
            );
          },
        ),
      );
      if (saved == true) {
        await widget.scheduleStore.add(controller.text, selectedDate);
        await _load();
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _toggle(ScheduleItem item) async {
    await widget.scheduleStore.toggle(item);
  }

  Future<void> _remove(ScheduleItem item) async {
    await widget.scheduleStore.remove(item);
  }

  String _formatDate(DateTime value) {
    final time = TimeOfDay.fromDateTime(value).format(context);
    return '${value.day}/${value.month}/${value.year} • $time';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcomingReminders = widget.scheduleStore.items
        .where((item) => !item.completed && item.dateTime.isAfter(now))
        .take(5)
        .toList();
    final upcomingAppointments = _appointmentItems
        .where((item) => item.status == AppointmentStatus.upcoming && item.startsAt.isAfter(now))
        .take(3)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('متنساش مواعيدك', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('تذكير جديد'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('كل اللي مهم… في مكان واحد', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('مواعيدك، أدويةك، والتذكيرات اليومية بدون ما تضيع منك حاجة.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(child: _StatTile(icon: Icons.notifications_active_rounded, value: '${widget.scheduleStore.items.where((e) => !e.completed && e.dateTime.isAfter(now)).length}', label: 'تذكيرات قادمة')),
                          Expanded(child: _StatTile(icon: Icons.event_available_rounded, value: '${_appointmentItems.where((e) => e.status == AppointmentStatus.upcoming).length}', label: 'مواعيد قادمة')),
                          Expanded(child: _StatTile(icon: Icons.medication_rounded, value: '$_medicationCount', label: 'أدوية')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _ModuleCard(
                icon: Icons.event_available_rounded,
                title: 'المواعيد',
                subtitle: 'زيارات، دكاترة، شغل، سفر، مكالمات ومتابعات.',
                count: '${_appointmentItems.where((e) => e.status == AppointmentStatus.upcoming).length} قادم',
                onTap: _openAppointments,
              ),
              const SizedBox(height: 10),
              _ModuleCard(
                icon: Icons.medication_rounded,
                title: 'الأدوية ومواعيد الجرعات',
                subtitle: 'احفظ الدواء والجرعة وأيام ووقت التذكير.',
                count: '$_medicationCount دواء',
                onTap: _openMedications,
              ),
              const SizedBox(height: 16),
              const Text('التذكيرات القادمة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              if (_loading)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
              else if (upcomingReminders.isEmpty && upcomingAppointments.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.check_circle_outline_rounded, size: 42),
                        SizedBox(height: 10),
                        Text('مفيش حاجة ناسيها دلوقتي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        SizedBox(height: 5),
                        Text('ضيف تذكير جديد أو سجّل أول موعد ليك.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else ...<Widget>[
                ...upcomingReminders.map((item) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.notifications_active_outlined)),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(_formatDate(item.dateTime)),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'done') await _toggle(item);
                            if (value == 'delete') await _remove(item);
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(value: 'done', child: Text('تم')),
                            PopupMenuItem(value: 'delete', child: Text('حذف')),
                          ],
                        ),
                      ),
                    )),
                ...upcomingAppointments.map((item) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('موعد • ${_formatDate(item.startsAt)}'),
                        onTap: _openAppointments,
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Icon(icon, size: 22),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.icon, required this.title, required this.subtitle, required this.count, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(radius: 23, child: Icon(icon)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      );
}
