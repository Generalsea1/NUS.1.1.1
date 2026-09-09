import 'package:flutter/material.dart';

import '../../expenses/domain/currency_registry.dart';
import '../domain/debt_payoff_plan.dart';

class DebtPayoffPlannerPage extends StatefulWidget {
  const DebtPayoffPlannerPage({
    super.key,
    required this.userId,
    required this.currencyCode,
  });

  final String userId;
  final String currencyCode;

  @override
  State<DebtPayoffPlannerPage> createState() => _DebtPayoffPlannerPageState();
}

class _DebtPayoffPlannerPageState extends State<DebtPayoffPlannerPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _balanceController;
  late final TextEditingController _paymentController;
  late final TextEditingController _extraController;
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));
  DebtPayoffPlan? _plan;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'دين');
    _balanceController = TextEditingController();
    _paymentController = TextEditingController();
    _extraController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _balanceController.dispose();
    _paymentController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    try {
      final balance = _parseMajor(_balanceController.text);
      final payment = _parseMajor(_paymentController.text);
      final extra = _parseMajor(_extraController.text, allowZero: true);
      final plan = DebtPayoffPlan(
        id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        userId: widget.userId,
        title: _titleController.text,
        currencyCode: widget.currencyCode,
        totalBalanceMinorUnits: balance,
        monthlyPaymentMinorUnits: payment,
        extraMonthlyPaymentMinorUnits: extra,
        firstDueDate: _firstDueDate,
      );
      setState(() {
        _plan = plan;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _plan = null;
        _error = error.toString().replaceFirst('ArgumentError: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _firstDueDate = DateTime(picked.year, picked.month, picked.day));
  }

  int _parseMajor(String input, {bool allowZero = false}) {
    final value = double.tryParse(input.trim().replaceAll(',', ''));
    if (value == null || value.isNaN || value.isInfinite || (value <= 0 && !allowZero)) {
      throw ArgumentError('أدخل مبلغًا صحيحًا أكبر من صفر.');
    }
    if (value < 0) throw ArgumentError('المبلغ لا يمكن أن يكون سالبًا.');
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final scaled = value * metadata.scale;
    if (scaled.roundToDouble() != scaled) {
      throw ArgumentError('دقة العملة الحالية لا تسمح بهذا العدد من الكسور.');
    }
    return scaled.round();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('مخطط سداد الديون')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'شوف الدين هينتهي إمتى قبل ما تاخد التزام جديد.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'ده سيناريو سداد حسابي بدون فائدة أو رسوم إضافية. الأرقام للقرار فقط ومش بتنشئ دينًا تلقائيًا.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'اسم الدين', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'الرصيد الحالي (${widget.currencyCode.toUpperCase()})', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paymentController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'السداد الشهري (${widget.currencyCode.toUpperCase()})', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _extraController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'دفعة إضافية شهرية اختيارية (${widget.currencyCode.toUpperCase()})', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text('أول استحقاق: ${_date(_firstDueDate)}'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('calculate-debt-payoff'),
              onPressed: _calculate,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('احسب خطة السداد'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_error!, key: const ValueKey<String>('debt-plan-error')),
                ),
              ),
            ],
            if (plan != null) ...[
              const SizedBox(height: 18),
              Card(
                key: const ValueKey<String>('debt-payoff-summary'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('إجمالي السداد الشهري: ${_money(plan.effectiveMonthlyPaymentMinorUnits)}'),
                      Text('عدد الأشهر التقريبي: ${plan.estimatedMonths}'),
                      Text('عدد الدفعات: ${plan.schedule.length}'),
                      const SizedBox(height: 12),
                      for (final item in plan.schedule.take(12))
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(radius: 15, child: Text('${item.number}')),
                          title: Text('استحقاق ${_date(item.dueDate)}'),
                          subtitle: Text('المتبقي: ${_money(item.remainingMinorUnits)}'),
                          trailing: Text(_money(item.paymentMinorUnits), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      if (plan.schedule.length > 12)
                        Text('عرضنا أول 12 دفعة فقط من الجدول.'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _money(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    if (metadata.exponent == 0) return '${minorUnits < 0 ? '-' : ''}${whole.toString()} ${metadata.code}';
    final fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${whole.toString()}.$fraction ${metadata.code}';
  }
}
