import 'package:flutter/material.dart';

import '../application/income_source_service.dart';
import '../application/income_source_validator.dart';
import '../domain/income_source.dart';

class IncomeManagementPage extends StatefulWidget {
  const IncomeManagementPage({
    super.key,
    required this.userId,
    required this.householdCurrencyCode,
    required this.service,
  });

  final String userId;
  final String householdCurrencyCode;
  final IncomeSourceService service;

  @override
  State<IncomeManagementPage> createState() => _IncomeManagementPageState();
}

class _IncomeManagementPageState extends State<IncomeManagementPage> {
  final _validator = const IncomeSourceValidator();
  List<IncomeSource> _sources = const <IncomeSource>[];
  bool _loading = true;
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
      final sources = await widget.service.list(widget.userId);
      if (!mounted) return;
      setState(() {
        _sources = List<IncomeSource>.of(sources, growable: false);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'مش قادرين نحمّل مصادر الدخل دلوقتي. جرّب تاني.';
      });
    }
  }

  int get _total => widget.service.totalMonthlyIncome(
        _sources,
        currencyCode: widget.householdCurrencyCode,
      );

  Future<void> _openEditor([IncomeSource? source]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _IncomeEditor(
        source: source,
        userId: widget.userId,
        householdCurrencyCode: widget.householdCurrencyCode,
        service: widget.service,
        validator: _validator,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _toggle(IncomeSource source) async {
    final sourceId = source.id;
    if (sourceId == null) return;
    try {
      await widget.service.setEnabled(widget.userId, sourceId, !source.enabled);
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ماقدرناش نغيّر حالة مصدر الدخل. جرّب تاني.');
    }
  }

  Future<void> _delete(IncomeSource source) async {
    final sourceId = source.id;
    if (sourceId == null) return;
    if (source.sourceType == 'legacy') {
      setState(() => _error = 'مصدر الدخل الموروث من إعداد البيت محمي. عدّله بدل حذفه.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف مصدر الدخل؟'),
        content: Text('هيتم حذف «${source.name}» نهائيًا من حسابك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.delete(widget.userId, sourceId);
      if (mounted) await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ماقدرناش نحذف مصدر الدخل. بياناتك لسه موجودة، جرّب تاني.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('income-management-page'),
      appBar: AppBar(
        title: const Text('مصادر الدخل', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('income-add'),
        onPressed: _loading ? null : () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة دخل'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    Card(
                      key: const ValueKey<String>('income-total-card'),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إجمالي الدخل الشهري', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              '$_total ${widget.householdCurrencyCode}',
                              key: const ValueKey<String>('income-total-monthly'),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 6),
                            const Text('الإجمالي = المصادر المفعّلة فقط بعد تحويلها لأساس شهري ثابت.'),
                          ],
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(child: Text(_error!, key: const ValueKey<String>('income-error'))),
                              TextButton(key: const ValueKey<String>('income-retry-load'), onPressed: _load, child: const Text('إعادة المحاولة')),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_sources.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('لسه مفيش مصادر دخل محفوظة. أضف أول مصدر دخل حقيقي.'),
                        ),
                      )
                    else
                      ..._sources.map((source) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _IncomeSourceCard(
                              source: source,
                              currencyCode: widget.householdCurrencyCode,
                              onEdit: () => _openEditor(source),
                              onToggle: () => _toggle(source),
                              onDelete: () => _delete(source),
                            ),
                          )),
                  ],
                ),
              ),
      ),
    );
  }
}

class _IncomeSourceCard extends StatelessWidget {
  const _IncomeSourceCard({
    required this.source,
    required this.currencyCode,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final IncomeSource source;
  final String currencyCode;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  String _money(int value) => '$value $currencyCode';

  @override
  Widget build(BuildContext context) {
    final id = source.id ?? 'new';
    return Card(
      key: ValueKey<String>('income-source-$id'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(source.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                Switch(
                  key: ValueKey<String>('income-toggle-$id'),
                  value: source.enabled,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(IncomeSourceTypes.labels[source.sourceType] ?? source.sourceType),
            const SizedBox(height: 4),
            Text('${_money(source.amount)} · ${IncomeFrequencies.labels[source.frequency]}'),
            Text('المعادل الشهري: ${_money(source.normalizedMonthlyAmount)}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(key: ValueKey<String>('income-edit-$id'), onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل'))),
                if (source.sourceType != 'legacy') ...[
                  const SizedBox(width: 8),
                  IconButton(key: ValueKey<String>('income-delete-$id'), onPressed: onDelete, tooltip: 'حذف', icon: const Icon(Icons.delete_outline_rounded)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeEditor extends StatefulWidget {
  const _IncomeEditor({
    required this.source,
    required this.userId,
    required this.householdCurrencyCode,
    required this.service,
    required this.validator,
  });

  final IncomeSource? source;
  final String userId;
  final String householdCurrencyCode;
  final IncomeSourceService service;
  final IncomeSourceValidator validator;

  @override
  State<_IncomeEditor> createState() => _IncomeEditorState();
}

class _IncomeEditorState extends State<_IncomeEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late String _sourceType;
  late String _frequency;
  late bool _enabled;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final source = widget.source;
    _nameController = TextEditingController(text: source?.name ?? '');
    _amountController = TextEditingController(text: source == null ? '' : '${source.amount}');
    _currencyController = TextEditingController(text: source?.currencyCode ?? widget.householdCurrencyCode);
    _sourceType = source?.sourceType ?? 'salary';
    _frequency = source?.frequency ?? 'monthly';
    _enabled = source?.enabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null) {
      setState(() {
        _saving = false;
        _error = 'المبلغ لازم يكون رقم صحيح وموجب.';
      });
      return;
    }
    final source = IncomeSource(
      id: widget.source?.id,
      userId: widget.userId,
      name: _nameController.text,
      sourceType: _sourceType,
      amount: amount,
      currencyCode: _currencyController.text,
      frequency: _frequency,
      enabled: _enabled,
      createdAt: widget.source?.createdAt,
    );
    final validationError = widget.validator.validate(
      source,
      householdCurrencyCode: widget.householdCurrencyCode,
    );
    if (validationError != null) {
      setState(() {
        _saving = false;
        _error = validationError;
      });
      return;
    }
    try {
      if (_editing) {
        await widget.service.update(source);
      } else {
        await widget.service.create(source);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'ماقدرناش نحفظ مصدر الدخل. بياناتك مازالت في النموذج، جرّب تاني.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_editing ? 'تعديل مصدر الدخل' : 'إضافة مصدر دخل', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey<String>('income-name'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'اسم مصدر الدخل'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'اكتب اسم مصدر الدخل.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('income-type'),
                  initialValue: _sourceType,
                  decoration: const InputDecoration(labelText: 'نوع الدخل'),
                  items: IncomeSourceTypes.values.map((value) => DropdownMenuItem(value: value, child: Text(IncomeSourceTypes.labels[value]!))).toList(growable: false),
                  onChanged: _saving || widget.source?.sourceType == 'legacy' ? null : (value) => setState(() => _sourceType = value ?? 'other'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('income-amount'),
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  validator: (value) {
                    final amount = int.tryParse(value?.trim() ?? '');
                    return amount == null || amount <= 0 ? 'المبلغ لازم يكون رقم صحيح وأكبر من صفر.' : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('income-currency'),
                  controller: _currencyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'العملة'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'اكتب العملة.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey<String>('income-frequency'),
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'التكرار'),
                  items: IncomeFrequencies.values.map((value) => DropdownMenuItem(value: value, child: Text(IncomeFrequencies.labels[value]!))).toList(growable: false),
                  onChanged: _saving ? null : (value) => setState(() => _frequency = value ?? 'monthly'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const ValueKey<String>('income-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مصدر الدخل مفعّل'),
                  value: _enabled,
                  onChanged: _saving ? null : (value) => setState(() => _enabled = value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, key: const ValueKey<String>('income-form-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey<String>('income-save'),
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ مصدر الدخل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
