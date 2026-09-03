import 'package:flutter/material.dart';

import '../application/medication_lifecycle_service.dart';
import '../domain/medication.dart';
import 'medication_details_page.dart';
import 'medication_editor_page.dart';

class MedicationsPage extends StatefulWidget {
  const MedicationsPage({
    super.key,
    required this.service,
    this.isArabic = true,
  });

  final MedicationLifecycleService service;
  final bool isArabic;

  @override
  State<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends State<MedicationsPage> {
  List<Medication> _items = const <Medication>[];
  bool _loading = true;
  String? _error;

  String t(String en, String ar) => widget.isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_loading && mounted) setState(() => _error = null);
    try {
      final items = await widget.service.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = t('Could not load medications.', 'تعذر تحميل الأدوية.');
      });
    }
  }

  Future<void> _add() async {
    final medication = await Navigator.of(context).push<Medication>(
      MaterialPageRoute(
        builder: (_) => MedicationEditorPage(isArabic: widget.isArabic),
      ),
    );
    if (!mounted || medication == null) return;
    await _save(medication);
  }

  Future<void> _edit(Medication medication) async {
    final updated = await Navigator.of(context).push<Medication>(
      MaterialPageRoute(
        builder: (_) => MedicationEditorPage(
          isArabic: widget.isArabic,
          initial: medication,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    await _save(updated, previous: medication);
  }

  Future<void> _save(Medication medication, {Medication? previous}) async {
    try {
      await widget.service.save(medication, previous: previous);
      await _load();
    } on ArgumentError {
      _message(t('Please review the medication details.', 'راجع بيانات الدواء.'));
    } on Object {
      _message(t('Could not save the medication.', 'تعذر حفظ الدواء.'));
      await _load();
    }
  }

  Future<void> _setActive(Medication medication, bool active) async {
    try {
      await widget.service.setActive(medication, active);
      await _load();
    } on Object {
      _message(t('Could not update medication status.', 'تعذر تحديث حالة الدواء.'));
      await _load();
    }
  }

  Future<void> _delete(Medication medication) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t('Delete medication?', 'تحذف الدواء؟')),
        content: Text(t('The medication and its managed reminders will be removed.', 'سيتم حذف الدواء وإلغاء تذكيراته المُدارة.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('Delete', 'حذف'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.delete(medication);
      await _load();
    } on Object {
      _message(t('Could not delete the medication.', 'تعذر حذف الدواء.'));
    }
  }

  Future<void> _details(Medication medication) async {
    final action = await Navigator.of(context).push<MedicationDetailsAction>(
      MaterialPageRoute(
        builder: (_) => MedicationDetailsPage(
          medication: medication,
          isArabic: widget.isArabic,
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MedicationDetailsAction.edit:
        await _edit(medication);
      case MedicationDetailsAction.delete:
        await _delete(medication);
      case MedicationDetailsAction.toggleActive:
        await _setActive(medication, !medication.isActive);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Medications', 'الأدوية'), style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('Add medication', 'إضافة دواء')),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(children: [const SizedBox(height: 100), _EmptyState(onAdd: _add, isArabic: widget.isArabic)])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final medication = _items[index];
                              return _MedicationCard(
                                medication: medication,
                                isArabic: widget.isArabic,
                                onTap: () => _details(medication),
                                onToggle: (value) => _setActive(medication, value),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication, required this.isArabic, required this.onTap, required this.onToggle});

  final Medication medication;
  final bool isArabic;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  String t(String en, String ar) => isArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    final dosageUnit = medication.dosage.unit == DosageUnit.custom
        ? (medication.dosage.customUnit ?? t('Custom', 'مخصص'))
        : _unitLabel(medication.dosage.unit);
    final scheduleSummary = medication.schedules.length == 1
        ? _scheduleLabel(medication.schedules.first)
        : '${medication.schedules.length} ${t('schedules', 'مواعيد')}';
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(child: const Icon(Icons.medication_outlined)),
        title: Text(medication.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${medication.dosage.amount} $dosageUnit • $scheduleSummary'),
        trailing: Switch.adaptive(value: medication.isActive, onChanged: onToggle),
      ),
    );
  }

  String _unitLabel(DosageUnit unit) => switch (unit) {
        DosageUnit.tablet => t('tablet', 'قرص'),
        DosageUnit.capsule => t('capsule', 'كبسولة'),
        DosageUnit.ml => 'ml',
        DosageUnit.drop => t('drop', 'نقطة'),
        DosageUnit.puff => t('puff', 'بَخّة'),
        DosageUnit.injection => t('injection', 'حقنة'),
        DosageUnit.custom => t('custom', 'مخصص'),
      };

  String _scheduleLabel(MedicationSchedule schedule) {
    final hour = schedule.minutesSinceMidnight ~/ 60;
    final minute = schedule.minutesSinceMidnight % 60;
    final time = TimeOfDay(hour: hour, minute: minute).format(context);
    return '$time • ${schedule.frequency == MedicationFrequency.daily ? t('Daily', 'يومي') : t('Selected weekdays', 'أيام محددة')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.isArabic});

  final VoidCallback onAdd;
  final bool isArabic;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              const Icon(Icons.medication_outlined, size: 48),
              const SizedBox(height: 14),
              Text(isArabic ? 'لسه مفيش أدوية' : 'No medications yet', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(isArabic ? 'أضف أول دواء واحفظ مواعيد جرعاته وتذكيراته في مكان واحد.' : 'Add your first medication and keep its schedules and reminders together.', textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: Text(isArabic ? 'إضافة دواء' : 'Add medication')),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
          ]),
        ),
      );
}
