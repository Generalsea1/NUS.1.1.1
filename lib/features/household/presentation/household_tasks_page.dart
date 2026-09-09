import 'package:flutter/material.dart';

import '../application/household_task_service.dart';
import '../data/supabase_household_task_repository.dart';
import '../domain/household_task.dart';
import '../domain/household.dart';

class HouseholdTasksPage extends StatefulWidget {
  const HouseholdTasksPage({
    super.key,
    required this.household,
    required this.currentMembership,
    this.service,
  });

  final Household household;
  final HouseholdMember currentMembership;
  final HouseholdTaskService? service;

  @override
  State<HouseholdTasksPage> createState() => _HouseholdTasksPageState();
}

class _HouseholdTasksPageState extends State<HouseholdTasksPage> {
  late final HouseholdTaskService _service =
      widget.service ?? HouseholdTaskService(repository: const SupabaseHouseholdTaskRepository());
  List<HouseholdTask> _tasks = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _service.list(widget.household.id);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل مهام البيت الآن.';
      });
    }
  }

  Future<void> _addTask() async {
    if (_saving) return;
    final controller = TextEditingController();
    DateTime? dueAt;
    try {
      final result = await showDialog<(String, DateTime?)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setLocalState) => AlertDialog(
            title: const Text('مهمة جديدة للبيت'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'المهمة',
                    hintText: 'مثال: دفع فاتورة الكهرباء',
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(
                    dueAt == null
                        ? 'بدون موعد'
                        : MaterialLocalizations.of(context).formatFullDate(dueAt!),
                  ),
                  trailing: dueAt == null
                      ? TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                              initialDate: DateTime.now(),
                            );
                            if (picked != null) setLocalState(() => dueAt = picked);
                          },
                          child: const Text('اختيار'),
                        )
                      : IconButton(
                          onPressed: () => setLocalState(() => dueAt = null),
                          icon: const Icon(Icons.clear_rounded),
                        ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop((controller.text, dueAt)),
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || result == null || result.$1.trim().isEmpty) return;
      setState(() => _saving = true);
      await _service.create(
        householdId: widget.household.id,
        createdBy: widget.currentMembership.userId,
        title: result.$1,
        dueAt: result.$2,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إضافة المهمة.')),
        );
      }
    } finally {
      controller.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(HouseholdTask task) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.setCompleted(task, !task.completed);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث حالة المهمة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(HouseholdTask task) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المهمة؟'),
        content: Text(task.title),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('حذف')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.delete(task);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف المهمة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _tasks.where((task) => !task.completed).toList(growable: false);
    final done = _tasks.where((task) => task.completed).toList(growable: false);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مهام البيت', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey<String>('household-task-add'),
          onPressed: _saving ? null : _addTask,
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('مهمة جديدة'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
                        title: Text('${active.length} مهام مفتوحة', style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('تم إنجاز ${done.length} مهام. كل عضو نشط في البيت يرى نفس القائمة.'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة'))])))
                    else if (_tasks.isEmpty)
                      const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('مفيش مهام مشتركة لسه. أضف أول مهمة للبيت.')))
                    else ...[
                      for (final task in _tasks)
                        Card(
                          child: ListTile(
                            leading: Checkbox(
                              value: task.completed,
                              onChanged: _saving ? null : (_) => _toggle(task),
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                decoration: task.completed ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              task.dueAt == null
                                  ? 'بدون موعد'
                                  : 'الموعد: ${MaterialLocalizations.of(context).formatShortDate(task.dueAt!.toLocal())}',
                            ),
                            trailing: IconButton(
                              tooltip: 'حذف',
                              onPressed: _saving ? null : () => _delete(task),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
