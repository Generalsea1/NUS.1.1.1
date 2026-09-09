import 'package:flutter/material.dart';

import '../application/installment_plan_service.dart';
import '../data/supabase_installment_plan_repository.dart';
import '../domain/installment_plan.dart';
import '../../expenses/domain/currency_registry.dart';

class InstallmentPlannerPage extends StatefulWidget {
  const InstallmentPlannerPage({
    super.key,
    required this.userId,
    required this.currencyCode,
    this.planService,
  });

  final String userId;
  final String currencyCode;
  final InstallmentPlanService? planService;

  @override
  State<InstallmentPlannerPage> createState() => _InstallmentPlannerPageState();
}

class _InstallmentPlannerPageState extends State<InstallmentPlannerPage> {
  final _totalController = TextEditingController();
  final _downPaymentController = TextEditingController(text: '0');
  final _countController = TextEditingController(text: '6');
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));
  InstallmentPlan? _plan;
  String? _error;
  bool _saving = false;
  bool _saved = false;

  @override
  void dispose() {
    _totalController.dispose();
    _downPaymentController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _calculate() {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final totalMinor = _parseMoneyMinor(_totalController.text, metadata);
    final downMinor = _parseMoneyMinor(_downPaymentController.text, metadata) ?? 0;
    final count = int.tryParse(_countController.text.trim());

    if (totalMinor == null || count == null || totalMinor <= 0 || downMinor < 0 || count <= 0) {
      setState(() {
        _plan = null;
        _saved = false;
        _error = 'راجع المبلغ والمقدم وعدد الأقساط. استخدم أرقام صحيحة حسب دقة العملة.';
      });
      return;
    }

    try {
      final plan = InstallmentPlan(
        id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        userId: widget.userId,
        title: 'خطة قسط',
        currencyCode: metadata.code,
        totalMinorUnits: totalMinor,
        downPaymentMinorUnits: downMinor,
        numberOfInstallments: count,
        paidInstallments: 0,
        firstDueDate: _firstDueDate,
      );
      setState(() {
        _plan = plan;
        _saved = false;
        _error = null;
      });
    } catch (_) {
      setState(() {
        _plan = null;
        _saved = false;
        _error = 'القيم الحالية لا تكوّن خطة أقساط صحيحة.';
      });
    }
  }

  int? _parseMoneyMinor(String raw, CurrencyMetadata metadata) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (var i = 0; i < arabicDigits.length; i++) {
      text = text.replaceAll(arabicDigits[i], '$i');
    }
    text = text.replaceAll(',', '.').replaceAll('٫', '.');
    final pattern = metadata.exponent == 0
        ? RegExp(r'^\d+$')
        : RegExp(r'^\d+(?:\.\d{1,' + metadata.exponent.toString() + r'})?$');
    if (!pattern.hasMatch(text)) return null;

    final separator = text.indexOf('.');
    final wholeText = separator == -1 ? text : text.substring(0, separator);
    final fractionText = separator == -1 ? '' : text.substring(separator + 1);
    final whole = int.tryParse(wholeText);
    if (whole == null) return null;
    final paddedFraction = fractionText.padRight(metadata.exponent, '0');
    final fraction = paddedFraction.isEmpty ? 0 : int.tryParse(paddedFraction);
    if (fraction == null) return null;
    return whole * metadata.scale + fraction;
  }

  Future<void> _pickFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(DateTime.now()),
      lastDate: DateUtils.dateOnly(DateTime.now().add(const Duration(days: 3650))),
      initialDate: _firstDueDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _firstDueDate = DateUtils.dateOnly(picked);
      _saved = false;
    });
  }

  Future<void> _savePlan() async {
    final plan = _plan;
    if (plan == null || _saving || _saved) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حفظ خطة الأقساط؟'),
        content: Text(
          'سيتم حفظ «${plan.title}» كخطة أقساط في حسابك. لا يتم إنشاء مصروف فعلي من هذه الخطوة.\n\n'
          'إجمالي التمويل: ${_money(plan.financedMinorUnits)}\n'
          'عدد الأقساط: ${plan.numberOfInstallments}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('حفظ الخطة')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final service = widget.planService ??
          InstallmentPlanService(repository: const SupabaseInstallmentPlanRepository());
      await service.create(
        InstallmentPlan(
          id: 'persist-${DateTime.now().microsecondsSinceEpoch}',
          userId: plan.userId,
          title: plan.title,
          currencyCode: plan.currencyCode,
          totalMinorUnits: plan.totalMinorUnits,
          downPaymentMinorUnits: plan.downPaymentMinorUnits,
          numberOfInstallments: plan.numberOfInstallments,
          paidInstallments: plan.paidInstallments,
          firstDueDate: plan.firstDueDate,
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ خطة الأقساط بنجاح.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'تعذر حفظ خطة الأقساط. لم يتم اعتبار العملية ناجحة.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('مخطط الأقساط')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Text(
            'احسب القسط وتوزيع المبلغ قبل ما تسجل أي التزام فعلي.',
            style: TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('installment-total'),
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'إجمالي المبلغ (${widget.currencyCode})',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('installment-down-payment'),
            controller: _downPaymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'المقدم (${widget.currencyCode})',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('installment-count'),
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'عدد الأقساط',
              prefixIcon: Icon(Icons.format_list_numbered_rounded),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.event_outlined)),
              title: const Text('أول موعد استحقاق'),
              subtitle: Text(MaterialLocalizations.of(context).formatFullDate(_firstDueDate)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickFirstDueDate,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey<String>('installment-calculate'),
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('احسب الخطة'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (plan != null) ...[
            const SizedBox(height: 16),
            Card(
              key: const ValueKey<String>('installment-summary'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('المبلغ المموّل: ${_money(plan.financedMinorUnits)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('المتبقي: ${_money(plan.remainingBalanceMinorUnits)}'),
                    const SizedBox(height: 6),
                    Text('عدد الأقساط: ${plan.numberOfInstallments}'),
                    const SizedBox(height: 6),
                    const Text('الخطة المحفوظة لا تعني سدادًا تلقائيًا ولا تنشئ مصروفات فعلية.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey<String>('installment-save'),
                      onPressed: _saving || _saved ? null : _savePlan,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_saved ? Icons.check_circle_outline_rounded : Icons.save_outlined),
                      label: Text(_saved ? 'تم حفظ الخطة' : 'حفظ الخطة في حسابي'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 1; index <= plan.numberOfInstallments; index++)
              Card(
                key: ValueKey<String>('installment-row-$index'),
                child: ListTile(
                  leading: CircleAvatar(child: Text('$index')),
                  title: Text('${_money(plan.installmentAmountMinorUnits(index))}'),
                  subtitle: Text(MaterialLocalizations.of(context).formatFullDate(plan.dueDateFor(index))),
                  trailing: index <= plan.paidInstallments
                      ? const Icon(Icons.check_circle_rounded)
                      : const Icon(Icons.schedule_rounded),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _money(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = metadata.exponent == 0
        ? ''
        : '.${(absolute % metadata.scale).toString().padLeft(metadata.exponent, '0')}';
    return '${minorUnits < 0 ? '-' : ''}${whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')}$fraction ${metadata.code}';
  }
}
