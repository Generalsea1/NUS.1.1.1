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
  int _scenarioMonths = 6;
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
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final minor = _parseMoneyMinor(_amountController.text, metadata);
    if (minor == null || minor <= 0) {
      setState(() {
        _error = 'اكتب مبلغ صحيح أكبر من صفر وبدون كسور أكتر من دقة العملة.';
        _assessment = null;
      });
      return;
    }

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
        scenarioMonths: _scenarioMonths,
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
    final match = pattern.firstMatch(text);
    if (match == null) return null;

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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onChanged: _loading
                  ? null
                  : (value) => setState(() {
                        _recurring = value;
                        if (!value) _scenarioMonths = 1;
                      }),
              title: const Text('التزام متكرر كل شهر'),
              subtitle: const Text('الحسبة تظل قراءة فقط ولا تحفظ أي عملية.'),
            ),
            if (_recurring) ...[
              const SizedBox(height: 4),
              DropdownButtonFormField<int>(
                key: const ValueKey<String>('affordability-scenario-months'),
                initialValue: _scenarioMonths,
                decoration: const InputDecoration(
                  labelText: 'مدة السيناريو',
                  prefixIcon: Icon(Icons.timeline_rounded),
                ),
                items: [
                  for (var months = 1; months <= 12; months++)
                    DropdownMenuItem<int>(
                      value: months,
                      child: Text('$months ${months == 1 ? 'شهر' : 'شهور'}'),
                    ),
                ],
                onChanged: _loading || !_recurring
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _scenarioMonths = value);
                      },
              ),
            ],
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
            if (assessment.horizonMonths > 1) ...[
              _line('مدة السيناريو', assessment.horizonMonths, suffix: assessment.horizonMonths == 1 ? 'شهر' : 'شهور', rawValue: true),
              _line('أقل سيولة في السيناريو', assessment.minimumProjectedFreeCashMinorUnits),
            ],
            const Divider(height: 20),
            _line('السيولة بعد المبلغ', assessment.resultingFreeCashMinorUnits),
            const SizedBox(height: 10),
            Text(
              assessment.horizonMonths > 1
                  ? 'سيناريو ضغط فقط: نفترض ثبات بيانات الشهر الحالي وتكرار المبلغ شهريًا. ده مش توقع للمستقبل.'
                  : 'الحسبة مبنية على بيانات الشهر المختار فقط، ومن هنا لا يتم حفظ أي عملية.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String label, int value, {bool rawValue = false, String? suffix}) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(
              rawValue ? '$value ${suffix ?? ''}'.trim() : _money(value),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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
