import 'package:flutter/material.dart';

import '../application/affordability_service.dart';
import '../domain/affordability.dart';
import '../../expenses/domain/currency_registry.dart';

class AffordabilityPage extends StatefulWidget {
  const AffordabilityPage({
    super.key,
    required this.userId,
    required this.year,
    required this.month,
    required this.currencyCode,
    required this.service,
  });

  final String userId;
  final int year;
  final int month;
  final String currencyCode;
  final AffordabilityService service;

  @override
  State<AffordabilityPage> createState() => _AffordabilityPageState();
}

class _AffordabilityPageState extends State<AffordabilityPage> {
  final _amountController = TextEditingController();
  bool _recurring = false;
  bool _loading = false;
  Object? _error;
  AffordabilityAssessment? _assessment;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _assess() async {
    if (_loading) return;
    final major = int.tryParse(_amountController.text.trim());
    if (major == null || major <= 0) {
      setState(() {
        _error = 'اكتب مبلغ صحيح أكبر من صفر.';
        _assessment = null;
      });
      return;
    }

    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final minor = major * metadata.scale;
    setState(() {
      _loading = true;
      _error = null;
      _assessment = null;
    });

    try {
      final assessment = await widget.service.assess(
        userId: widget.userId,
        year: widget.year,
        month: widget.month,
        currencyCode: widget.currencyCode,
        proposedMinorUnits: minor,
        recurring: _recurring,
      );
      if (!mounted) return;
      setState(() {
        _assessment = assessment;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessment = _assessment;
    return Scaffold(
      appBar: AppBar(title: const Text('هل أقدر أعمل ده؟')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'قبل ما تلتزم بالمبلغ، خلّي NUS يحسبه على أرقامك الحالية.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'دي حسبة معلوماتية فقط. NUS لا ينشئ مصروفًا أو دينًا أو التزامًا من هنا.',
            ),
            const SizedBox(height: 18),
            TextField(
              key: const ValueKey<String>('affordability-amount-input'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'المبلغ',
                suffixText: widget.currencyCode,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              key: const ValueKey<String>('affordability-recurring-toggle'),
              value: _recurring,
              onChanged: _loading ? null : (value) => setState(() => _recurring = value),
              title: const Text('التزام متكرر كل شهر'),
              subtitle: const Text('الحسبة تظل قراءة فقط ولا تحفظ أي عملية.'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey<String>('affordability-assess-button'),
              onPressed: _loading ? null : _assess,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('احسب'),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Card(
                key: ValueKey<String>('affordability-loading'),
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_error != null)
              Card(
                key: const ValueKey<String>('affordability-error'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(_error.toString()),
                ),
              )
            else if (assessment != null)
              _result(context, assessment),
          ],
        ),
      ),
    );
  }

  Widget _result(BuildContext context, AffordabilityAssessment assessment) {
    final scheme = Theme.of(context).colorScheme;
    final positive = assessment.status == AffordabilityStatus.affordable;
    final pressure = assessment.status == AffordabilityStatus.pressure;
    final title = positive
        ? 'المبلغ داخل المساحة المتاحة'
        : pressure
            ? 'ممكن، لكن هيضغط على السيولة'
            : 'المبلغ أكبر من المساحة الحالية';
    final icon = positive
        ? Icons.check_circle_outline_rounded
        : pressure
            ? Icons.warning_amber_rounded
            : Icons.block_rounded;
    return Card(
      key: const ValueKey<String>('affordability-result'),
      color: positive
          ? scheme.primaryContainer
          : pressure
              ? scheme.tertiaryContainer
              : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _line('المبلغ المقترح', assessment.proposedMinorUnits),
            _line('المصروف الفعلي المسجل', assessment.existingActualExpensesMinorUnits),
            _line('بعد الالتزامات', assessment.monthlyObligationsMinorUnits),
            const Divider(height: 20),
            _line('السيولة بعد المبلغ', assessment.resultingFreeCashMinorUnits),
            const SizedBox(height: 10),
            Text(
              'الحسبة مبنية على بيانات الشهر المختار فقط، ومن هنا لا يتم حفظ أي عملية.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, int minorUnits) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(_money(minorUnits), style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );

  String _money(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = metadata.exponent == 0
        ? ''
        : '.${(absolute % metadata.scale).toString().padLeft(metadata.exponent, '0')}';
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
}
