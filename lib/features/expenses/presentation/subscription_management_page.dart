import 'package:flutter/material.dart';

import '../application/expense_management_service.dart';
import '../data/supabase_expense_repository.dart';
import '../data/supabase_recurring_expense_repository.dart';
import '../domain/expense_category.dart';
import '../domain/recurring_expense_definition.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({
    super.key,
    required this.userId,
    required this.currencyCode,
    this.service,
  });

  final String userId;
  final String currencyCode;
  final ExpenseManagementService? service;

  @override
  State<SubscriptionManagementPage> createState() => _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage> {
  late final ExpenseManagementService _service = widget.service ??
      ExpenseManagementService(
        expenseRepository: const SupabaseExpenseRepository(),
        recurringRepository: const SupabaseRecurringExpenseRepository(),
      );

  List<RecurringExpenseDefinition> _subscriptions = const [];
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
      final definitions = await _service.listRecurring();
      final currency = widget.currencyCode.trim().toUpperCase();
      final filtered = definitions.where((definition) {
        if (definition.amount.currencyCode != currency) return false;
        return definition.categoryCode == 'subscriptions' || _looksLikeSubscription(definition.name);
      }).toList(growable: false)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _subscriptions = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل الاشتراكات حاليًا.';
      });
    }
  }

  bool _looksLikeSubscription(String name) {
    final value = name.trim().toLowerCase();
    const signals = <String>[
      'netflix',
      'spotify',
      'youtube',
      'amazon',
      'prime',
      'disney',
      'apple',
      'google one',
      'icloud',
      'adobe',
      'chatgpt',
      'اشتراك',
      'نتفلكس',
      'سبوتيفاي',
      'يوتيوب',
    ];
    return signals.any(value.contains);
  }

  Future<void> _toggle(RecurringExpenseDefinition definition) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.setRecurringEnabled(widget.userId, definition.id, !definition.enabled);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تغيير حالة الاشتراك.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(RecurringExpenseDefinition definition) async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الاشتراك؟'),
        content: Text('سيتم حذف ${definition.name} من المصروفات المتكررة.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('حذف')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _service.deleteRecurring(definition.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حذف الاشتراك.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _money(int minorUnits) {
    final value = minorUnits / 100;
    return '${value.toStringAsFixed(2)} ${widget.currencyCode.toUpperCase()}';
  }

  String _frequencyLabel(String frequency) {
    return ObligationFrequencyLabel.label(frequency);
  }

  @override
  Widget build(BuildContext context) {
    final active = _subscriptions.where((item) => item.enabled).fold<int>(0, (sum, item) => sum + item.normalizedMonthlyAmount);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاشتراكات', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.autorenew_rounded)),
                        title: Text('${_subscriptions.length} اشتراكات معروفة', style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text('التكلفة الشهرية النشطة: ${_money(active)}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة'))])))
                    else if (_subscriptions.isEmpty)
                      const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('لم نعثر على اشتراكات متكررة في هذه العملة. أضف مصروفًا متكررًا وصنّفه كـ«الاشتراكات» ليظهر هنا.')))
                    else
                      for (final definition in _subscriptions)
                        Card(
                          child: ListTile(
                            leading: Icon(definition.enabled ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded),
                            title: Text(definition.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${_money(definition.amount.minorUnits)} • ${_frequencyLabel(definition.frequency)} • ${ExpenseCategories.labelsAr[definition.categoryCode] ?? definition.categoryCode}'),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'toggle') _toggle(definition);
                                if (value == 'delete') _delete(definition);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'toggle', child: Text(definition.enabled ? 'إيقاف مؤقت' : 'تفعيل')),
                                const PopupMenuItem(value: 'delete', child: Text('حذف')),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
      ),
    );
  }
}

class ObligationFrequencyLabel {
  const ObligationFrequencyLabel._();

  static String label(String frequency) {
    switch (frequency) {
      case 'monthly':
        return 'شهري';
      case 'weekly':
        return 'أسبوعي';
      case 'biweekly':
        return 'كل أسبوعين';
      case 'quarterly':
        return 'ربع سنوي';
      case 'yearly':
        return 'سنوي';
      default:
        return frequency;
    }
  }
}
