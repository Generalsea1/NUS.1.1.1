import 'package:flutter/material.dart';

import '../domain/installment_plan.dart';
import '../../expenses/domain/currency_registry.dart';

class InstallmentPlannerPage extends StatefulWidget {
  const InstallmentPlannerPage({
    super.key,
    required this.userId,
    required this.currencyCode,
  });

  final String userId;
  final String currencyCode;

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

  @override
  void dispose() {
    _totalController.dispose();
    _downPaymentController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _calculate() {
    final totalMajor = int.tryParse(_totalController.text.trim());
    final downMajor = int.tryParse(_downPaymentController.text.trim()) ?? 0;
    final count = int.tryParse(_countController.text.trim());
    if (totalMajor == null || count == null || totalMajor <= 0 || downMajor < 0 || count <= 0) {
      setState(() {
        _plan = null;
        _error = 'راجع المبلغ والإمكانيات: كل القيم لازم تكون أرقام صحيحة وموجبة حسب الحقل.';
      });
      return;
    }

    try {
      final currency = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
      final totalMinor = CurrencyRegistry.majorToMinor(totalMajor, currency.code);
      final downMinor = CurrencyRegistry.majorToMinor(downMajor, currency.code);
      final plan = InstallmentPlan(
        id: 'preview-${DateTime.now().microsecondsSinceEpoch}',
        userId: widget.userId,
        title: 'خطة قسط',
        currencyCode: currency.code,
        totalMinorUnits: totalMinor,
        downPaymentMinorUnits: downMinor,
        numberOfInstallments: count,
        paidInstallments: 0,
        firstDueDate: _firstDueDate,
      );
      setState(() {
        _plan = plan;
        _error = null;
      });
    } catch (_) {
      setState(() {
        _plan = null;
        _error = 'القيم الحالية لا تكوّن خطة أقساط صحيحة.';
      });
    }
  }

  Future<void> _pickFirstDueDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _firstDueDate,
    );
    if (picked == null || !mounted) return;
    setState(() => _firstDueDate = DateUtils.dateOnly(picked));
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
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'إجمالي المبلغ (${widget.currencyCode})',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey<String>('installment-down-payment'),
            controller: _downPaymentController,
            keyboardType: TextInputType.number,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المبلغ المموّل: ${_money(plan.financedMinorUnits)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('المتبقي: ${_money(plan.remainingBalanceMinorUnits)}'),
                    const SizedBox(height: 6),
                    Text('عدد الأقساط: ${plan.numberOfInstallments}'),
                    const SizedBox(height: 6),
                    Text('الخطة للعرض والحساب فقط — لا يتم حفظ التزام تلقائيًا.'),
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
    return '${minorUnits < 0 ? '-' : ''}${whole.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')} ${metadata.code}';
  }
}
