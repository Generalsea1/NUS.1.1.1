import 'package:flutter/material.dart';

import '../../expenses/domain/currency_registry.dart';
import '../../expenses/domain/money.dart';
import '../application/financial_goal_service.dart';
import '../data/local_financial_goal_repository.dart';
import '../domain/financial_goal.dart';

class FinancialGoalsPage extends StatefulWidget {
  FinancialGoalsPage({super.key, required this.userId, required this.householdCurrencyCode, FinancialGoalService? service})
      : service = service ?? FinancialGoalService(repository: LocalFinancialGoalRepository());

  final String userId;
  final String householdCurrencyCode;
  final FinancialGoalService service;

  @override
  State<FinancialGoalsPage> createState() => _FinancialGoalsPageState();
}

class _FinancialGoalsPageState extends State<FinancialGoalsPage> {
  List<FinancialGoal> _goals = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final goals = await widget.service.list(widget.userId);
      if (!mounted) return;
      setState(() { _goals = goals; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _goals = const []; _loading = false; _error = error; });
    }
  }

  List<FinancialGoal> get _activeGoals => _goals.where((goal) => goal.status != FinancialGoalStatus.completed).toList(growable: false);
  List<FinancialGoal> get _completedGoals => _goals.where((goal) => goal.status == FinancialGoalStatus.completed).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأهداف المالية')),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey<String>('financial-goal-create'),
        onPressed: _loading ? null : _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('هدف جديد'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              Text('خلّي فلوسك رايحة لحاجة محددة.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('الأهداف بيانات تخطيط فقط؛ مش بننشئ مصروفات أو دخل أو مدفوعات علشان نمثل التقدم.'),
              const SizedBox(height: 18),
              if (_loading)
                const Card(key: ValueKey<String>('financial-goals-loading'), child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
              else if (_error != null)
                Card(
                  key: const ValueKey<String>('financial-goals-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      const Icon(Icons.cloud_off_rounded, size: 42),
                      const SizedBox(height: 10),
                      const Text('تعذر تحميل الأهداف المالية الآن.'),
                      const SizedBox(height: 8),
                      TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              else ...[
                if (_activeGoals.isEmpty)
                  _emptyCard(key: const ValueKey<String>('financial-goals-empty'), icon: Icons.flag_outlined, title: 'مفيش أهداف نشطة دلوقتي', message: 'ابدأ بهدف بسيط، وحدد له مبلغ ووقت لو حابب.')
                else ...[
                  _sectionHeader(context, 'الأهداف الحالية'),
                  const SizedBox(height: 10),
                  for (final goal in _activeGoals) ...[_goalCard(context, goal), const SizedBox(height: 12)],
                ],
                const SizedBox(height: 4),
                _sectionHeader(context, 'الأهداف المكتملة'),
                const SizedBox(height: 10),
                if (_completedGoals.isEmpty)
                  _emptyCard(key: const ValueKey<String>('financial-goals-completed-empty'), icon: Icons.check_circle_outline_rounded, title: 'لسه مفيش أهداف مكتملة', message: 'لما المبلغ الحالي يوصل للهدف، هيتنقل هنا تلقائيًا.')
                else
                  for (final goal in _completedGoals) ...[_goalCard(context, goal, completed: true), const SizedBox(height: 12)],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900));

  Widget _emptyCard({required Key key, required IconData icon, required String title, required String message}) => Card(
        key: key,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [Icon(icon, size: 42), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text(message, textAlign: TextAlign.center)]),
        ),
      );

  Widget _goalCard(BuildContext context, FinancialGoal goal, {bool completed = false}) {
    final progress = goal.progressPercent;
    final remaining = goal.remainingAmount;
    final days = goal.daysRemaining();
    final daily = goal.requiredDailySaving();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey<String>('financial-goal-${goal.id}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(child: Icon(completed ? Icons.verified_rounded : goal.status == FinancialGoalStatus.paused ? Icons.pause_rounded : Icons.flag_rounded)),
            const SizedBox(width: 12),
            Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
            PopupMenuButton<String>(
              key: ValueKey<String>('financial-goal-menu-${goal.id}'),
              onSelected: (value) => _handleGoalAction(goal, value),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                if (!completed && goal.status == FinancialGoalStatus.active) const PopupMenuItem(value: 'pause', child: Text('إيقاف مؤقت')),
                if (!completed && goal.status == FinancialGoalStatus.paused) const PopupMenuItem(value: 'resume', child: Text('استئناف')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ]),
          if (goal.status == FinancialGoalStatus.paused) ...[const SizedBox(height: 8), const Chip(avatar: Icon(Icons.pause_rounded, size: 18), label: Text('متوقف مؤقتًا'))],
          const SizedBox(height: 14),
          _moneyLine('الهدف', goal.targetAmount.minorUnits, goal.targetAmount.currencyCode),
          _moneyLine('الحالي', goal.currentAmount?.minorUnits, goal.targetAmount.currencyCode),
          _moneyLine('المتبقي', remaining?.minorUnits, goal.targetAmount.currencyCode),
          const SizedBox(height: 10),
          if (progress == null) ...[const Text('التقدم غير متاح — المبلغ الحالي لسه مش مسجل.'), const SizedBox(height: 8), const LinearProgressIndicator(value: 0)]
          else ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('نسبة التقدم', style: TextStyle(fontWeight: FontWeight.w800)), Text('$progress%', style: TextStyle(fontWeight: FontWeight.w900, color: completed ? scheme.primary : null))]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress / 100, minHeight: 9)),
          ],
          if (goal.targetDate != null) ...[
            const SizedBox(height: 12),
            Text('الموعد: ${_dateLabel(goal.targetDate!)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (days != null) Text(days >= 0 ? 'متبقي $days يوم' : 'موعد الهدف فات بـ ${days.abs()} يوم'),
            if (daily != null) Text('الادخار اليومي المطلوب: ${_formatMinor(daily.minorUnits, daily.currencyCode)}'),
            if (progress == null) const Text('الادخار الدوري غير محسوب لأن المبلغ الحالي غير متاح.'),
            if (days != null && days <= 0 && remaining != null && remaining.minorUnits > 0) const Text('لا يمكن حساب ادخار دوري للموعد المنتهي بدون تخمين.'),
          ],
        ]),
      ),
    );
  }

  Widget _moneyLine(String label, int? minorUnits, String currencyCode) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [SizedBox(width: 84, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(minorUnits == null ? 'غير متاح' : _formatMinor(minorUnits, currencyCode), style: const TextStyle(fontWeight: FontWeight.w900)))]),
      );

  Future<void> _create() async {
    final draft = await _showEditor();
    if (draft == null) return;
    try {
      await widget.service.create(userId: widget.userId, name: draft.name, targetMinorUnits: draft.targetMinorUnits, targetCurrencyCode: draft.currencyCode, targetDate: draft.targetDate, currentMinorUnits: draft.currentMinorUnits);
      await _load();
    } catch (error) {
      if (mounted) _showError(_readableGoalError(error));
    }
  }

  Future<void> _edit(FinancialGoal goal) async {
    final draft = await _showEditor(goal: goal);
    if (draft == null) return;
    try {
      final updated = FinancialGoal(
        id: goal.id,
        userId: goal.userId,
        name: draft.name,
        targetAmount: Money(minorUnits: draft.targetMinorUnits, currencyCode: draft.currencyCode),
        targetDate: draft.targetDate,
        currentAmount: draft.currentMinorUnits == null ? null : Money(minorUnits: draft.currentMinorUnits!, currencyCode: draft.currencyCode),
        status: goal.status,
        createdAt: goal.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
      await widget.service.update(updated);
      await _load();
    } catch (error) {
      if (mounted) _showError(_readableGoalError(error));
    }
  }

  Future<void> _handleGoalAction(FinancialGoal goal, String action) async {
    try {
      switch (action) {
        case 'edit':
          await _edit(goal);
          return;
        case 'pause':
          await widget.service.pause(widget.userId, goal.id);
          break;
        case 'resume':
          await widget.service.resume(widget.userId, goal.id);
          break;
        case 'delete':
          if (!await _confirmDelete(goal)) return;
          await widget.service.delete(widget.userId, goal.id);
          break;
      }
      await _load();
    } catch (error) {
      if (mounted) _showError(_readableGoalError(error));
    }
  }

  Future<bool> _confirmDelete(FinancialGoal goal) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الهدف؟'),
        content: Text('هنحذف هدف "${goal.name}" من بيانات التخطيط.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<_GoalDraft?> _showEditor({FinancialGoal? goal}) => showDialog<_GoalDraft>(
        context: context,
        builder: (_) => _GoalEditorDialog(goal: goal, defaultCurrency: goal?.targetAmount.currencyCode ?? widget.householdCurrencyCode),
      );

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _readableGoalError(Object error) => error is ArgumentError ? error.message?.toString() ?? 'بيانات الهدف غير صالحة.' : 'تعذر حفظ الهدف المالي الآن.';

  String _formatMinor(int minorUnits, String currencyCode) {
    final metadata = CurrencyRegistry.get(currencyCode);
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = metadata.exponent == 0 ? '' : '.${(absolute % metadata.scale).toString().padLeft(metadata.exponent, '0')}';
    return '${minorUnits < 0 ? '-' : ''}${_group(whole)}$fraction ${metadata.code}';
  }

  String _group(int value) {
    final text = value.toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return parts.join(',');
  }

  String _dateLabel(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _GoalDraft {
  const _GoalDraft({required this.name, required this.targetMinorUnits, required this.currencyCode, required this.targetDate, required this.currentMinorUnits});
  final String name;
  final int targetMinorUnits;
  final String currencyCode;
  final DateTime? targetDate;
  final int? currentMinorUnits;
}

class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({this.goal, required this.defaultCurrency});
  final FinancialGoal? goal;
  final String defaultCurrency;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.goal?.name ?? '');
  late final TextEditingController _target = TextEditingController(text: widget.goal == null ? '' : _majorText(widget.goal!.targetAmount.minorUnits, widget.goal!.targetAmount.currencyCode));
  late final TextEditingController _current = TextEditingController(text: widget.goal?.currentAmount == null ? '' : _majorText(widget.goal!.currentAmount!.minorUnits, widget.goal!.targetAmount.currencyCode));
  late String _currency = widget.goal?.targetAmount.currencyCode ?? widget.defaultCurrency.trim().toUpperCase();
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    _targetDate = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.goal == null ? 'إنشاء هدف مالي' : 'تعديل الهدف المالي'),
      scrollable: true,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم الهدف')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('financial-goal-currency-$_currency'),
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'العملة'),
          items: CurrencyRegistry.supported.keys.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(growable: false),
          onChanged: (value) => setState(() { if (value != null) _currency = value; }),
        ),
        const SizedBox(height: 12),
        TextField(controller: _target, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'المبلغ المستهدف ($_currency)')),
        const SizedBox(height: 12),
        TextField(controller: _current, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'المبلغ الحالي ($_currency) — اختياري')),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text(_targetDate == null ? 'من غير موعد نهائي' : 'الموعد: ${_formatDate(_targetDate!)}')), TextButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today_rounded), label: Text(_targetDate == null ? 'اختيار موعد' : 'تغيير'))]),
        if (_targetDate != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _targetDate = null), child: const Text('إزالة الموعد'))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: _submit, child: Text(widget.goal == null ? 'إنشاء' : 'حفظ'))],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _targetDate ?? now, firstDate: DateTime(now.year, now.month, now.day), lastDate: DateTime(2100), helpText: 'اختار موعد الهدف', cancelText: 'إلغاء', confirmText: 'اختيار');
    if (picked != null && mounted) setState(() => _targetDate = DateTime.utc(picked.year, picked.month, picked.day));
  }

  void _submit() {
    final name = _name.text.trim();
    final target = _parseMajor(_target.text, _currency);
    final current = _current.text.trim().isEmpty ? null : _parseMajor(_current.text, _currency);
    if (name.isEmpty) return _error('اكتب اسم الهدف.');
    if (target == null || target <= 0) return _error('اكتب مبلغ مستهدف صحيح وأكبر من صفر.');
    if (current != null && current > target) return _error('المبلغ الحالي مينفعش يتخطى المبلغ المستهدف في الإصدار ده.');
    Navigator.pop(context, _GoalDraft(name: name, targetMinorUnits: target, currencyCode: _currency, targetDate: _targetDate, currentMinorUnits: current));
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  static int? _parseMajor(String value, String currencyCode) {
    final metadata = CurrencyRegistry.get(currencyCode);
    final clean = value.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(clean)) return null;
    final pieces = clean.split('.');
    final whole = int.tryParse(pieces.first);
    if (whole == null) return null;
    final fractionText = pieces.length == 1 ? '' : pieces[1];
    if (fractionText.length > metadata.exponent) return null;
    final fraction = fractionText.padRight(metadata.exponent, '0');
    final minorFraction = fraction.isEmpty ? 0 : int.tryParse(fraction);
    if (minorFraction == null) return null;
    return whole * metadata.scale + minorFraction;
  }

  static String _majorText(int minorUnits, String currencyCode) {
    final metadata = CurrencyRegistry.get(currencyCode);
    final whole = minorUnits ~/ metadata.scale;
    if (metadata.exponent == 0) return whole.toString();
    return '$whole.${(minorUnits % metadata.scale).toString().padLeft(metadata.exponent, '0')}';
  }

  static String _formatDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
