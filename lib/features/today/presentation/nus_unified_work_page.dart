import 'package:flutter/material.dart';

import '../../../legacy_main.dart' as legacy;
import '../../appointments/data/local_appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../household/application/household_task_service.dart';
import '../../household/domain/household_task.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/domain/obligation.dart';
import '../application/nus_unified_work_builder.dart';
import '../domain/nus_work_item.dart';

class NusUnifiedWorkPage extends StatefulWidget {
  const NusUnifiedWorkPage({
    super.key,
    required this.userId,
    this.householdId,
    required this.scheduleStore,
    required this.taskService,
    required this.obligationService,
  });

  final String userId;
  final String? householdId;
  final legacy.ScheduleStore scheduleStore;
  final HouseholdTaskService taskService;
  final ObligationService obligationService;

  @override
  State<NusUnifiedWorkPage> createState() => _NusUnifiedWorkPageState();
}

class _NusUnifiedWorkPageState extends State<NusUnifiedWorkPage> {
  final LocalAppointmentRepository _appointmentRepository = LocalAppointmentRepository();

  List<Appointment> _appointments = const [];
  List<HouseholdTask> _tasks = const [];
  List<Obligation> _obligations = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.scheduleStore.addListener(_refreshFromStore);
    _load();
  }

  @override
  void didUpdateWidget(covariant NusUnifiedWorkPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scheduleStore != widget.scheduleStore) {
      oldWidget.scheduleStore.removeListener(_refreshFromStore);
      widget.scheduleStore.addListener(_refreshFromStore);
    }
    if (oldWidget.userId != widget.userId || oldWidget.householdId != widget.householdId) {
      _load();
    }
  }

  @override
  void dispose() {
    widget.scheduleStore.removeListener(_refreshFromStore);
    super.dispose();
  }

  void _refreshFromStore() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final appointmentsFuture = _appointmentRepository.list();
      final tasksFuture = widget.householdId == null
          ? Future<List<HouseholdTask>>.value(const [])
          : widget.taskService.list(widget.householdId!);
      final obligationsFuture = widget.obligationService.list(widget.userId);

      final results = await Future.wait<Object>([
        appointmentsFuture,
        tasksFuture,
        obligationsFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _appointments = results[0] as List<Appointment>;
        _tasks = results[1] as List<HouseholdTask>;
        _obligations = results[2] as List<Obligation>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  List<NusWorkItem> _buildItems() {
    final reminders = widget.scheduleStore.items
        .map(
          (reminder) => NusWorkReminderInput(
            id: reminder.id,
            title: reminder.title,
            dueAt: reminder.dateTime,
            completed: reminder.completed,
          ),
        )
        .toList(growable: false);

    return NusUnifiedWorkBuilder.build(
      reminders: reminders,
      appointments: _appointments,
      householdTasks: _tasks,
      obligations: _obligations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();
    final next = items.isEmpty ? null : items.first;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'العمل الموحد',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            children: [
              _summaryCard(context, items, next),
              const SizedBox(height: 14),
              if (_error != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded),
                    title: const Text('تعذر تحديث كل المصادر'),
                    subtitle: Text(_error!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (_loading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text('مفيش عمل مفتوح دلوقتي. كل حاجة الحالية منتهية أو مفيش لها موعد.'),
                  ),
                )
              else
                _queueCard(items),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(BuildContext context, List<NusWorkItem> items, NusWorkItem? next) {
    final scheme = Theme.of(context).colorScheme;
    final overdue = items.where((item) => item.isOverdue).length;
    final today = items.where((item) {
      final due = item.dueAt;
      if (due == null || item.isOverdue) return false;
      final current = DateTime.now();
      return due.year == current.year && due.month == current.month && due.day == current.day;
    }).length;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NUS شايف الصورة كلها', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(
              next == null ? 'مفيش خطوة مفتوحة حاليًا.' : 'أول حاجة محتاجة انتباه: ${next.title}',
              style: TextStyle(height: 1.4, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metric('${items.length}', 'مفتوح'),
                _metric('$overdue', 'متأخر'),
                _metric('$today', 'النهارده'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$value $label', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _queueCard(List<NusWorkItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _workTile(items[i], i + 1),
              if (i != items.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workTile(NusWorkItem item, int position) {
    final due = item.dueAt;
    final subtitle = switch (item.kind) {
      NusWorkItemKind.reminder => 'تذكير',
      NusWorkItemKind.appointment => 'موعد',
      NusWorkItemKind.householdTask => 'مهمة البيت',
      NusWorkItemKind.obligation => item.amountMinorUnits == null
          ? 'التزام مالي'
          : 'التزام مالي • ${item.amountMinorUnits} ${item.currencyCode ?? ''}',
    };
    final timing = due == null
        ? 'بدون موعد'
        : item.isOverdue
            ? 'متأخر'
            : TimeOfDay.fromDateTime(due).format(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: CircleAvatar(child: Text('$position')),
      title: Text(item.title.isEmpty ? 'بدون عنوان' : item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('$subtitle • $timing'),
      trailing: Icon(item.isOverdue ? Icons.warning_amber_rounded : Icons.arrow_back_rounded),
    );
  }
}
