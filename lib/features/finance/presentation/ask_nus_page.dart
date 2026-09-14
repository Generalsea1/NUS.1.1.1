import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';

class AskNusPage extends StatefulWidget {
  const AskNusPage({super.key, required this.snapshot, this.provider = const FinancialAdvisorProvider(), this.initialQuestion});

  final FinancialAdvisorSnapshot snapshot;
  final AiInsightProvider provider;
  final String? initialQuestion;

  @override
  State<AskNusPage> createState() => _AskNusPageState();
}

class _AskNusPageState extends State<AskNusPage> {
  final _controller = TextEditingController();
  AiInsight? _answer;
  bool _loading = false;
  String? _error;

  static const _suggestedQuestions = <String>[
    'أين يذهب معظم إنفاقي هذا الشهر؟',
    'ما أول شيء أحتاج أن أعمله لتحسين وضعي المالي؟',
    'هل إنفاقي الحالي أعلى من قدرتي الآمنة؟',
    'كيف أتعامل مع الالتزامات قبل باقي المصروفات؟',
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuestion?.trim();
    if (initial != null && initial.isNotEmpty) {
      _controller.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask([String? question]) async {
    final text = (question ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    _controller.text = text;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _answer = null; });
    try {
      final request = widget.snapshot.toAiRequest();
      final insight = await widget.provider.generateInsight(AiInsightRequest(
        objective: '${request.objective}\nUser question: $text\nAnswer in clear Egyptian Arabic. Return a concise, prioritized recommendation. Use only supplied facts.',
        context: request.context,
      ));
      if (!mounted) return;
      setState(() { _answer = insight; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  String _money(int value) => '${_format(value)} ${widget.snapshot.financial.currencyCode}';
  String _minorMoney(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.snapshot.financial.currencyCode);
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }
  String _format(int value) {
    final raw = value.abs().toString();
    final chunks = <String>[];
    for (var i = raw.length; i > 0; i -= 3) { final start = i > 3 ? i - 3 : 0; chunks.insert(0, raw.substring(start, i)); }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final financial = widget.snapshot.financial;
    return Scaffold(
      appBar: AppBar(title: const Text('اسأل NUS', style: TextStyle(fontWeight: FontWeight.w900))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _intro(context),
            const SizedBox(height: 14),
            _liveContext(context, financial),
            const SizedBox(height: 14),
            Text('جرّب سؤالًا', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _suggestedQuestions.map((item) => ActionChip(label: Text(item), onPressed: _loading ? null : () => _ask(item))).toList(growable: false)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ask(),
              decoration: InputDecoration(
                labelText: 'اكتب سؤالك',
                hintText: 'مثال: هل أقدر ألتزم بقسط جديد هذا الشهر؟',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                suffixIcon: IconButton(onPressed: _loading ? null : () => _controller.clear(), icon: const Icon(Icons.clear_rounded)),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_rounded),
              label: Text(_loading ? 'NUS بيحلل الأرقام…' : 'اسأل NUS'),
            ),
            const SizedBox(height: 16),
            if (_error != null) _errorCard(context),
            if (_answer != null) _answerCard(context, _answer!),
          ],
        ),
      ),
      floatingActionButton: _answer == null ? null : FloatingActionButton.extended(onPressed: _loading ? null : () => setState(() => _answer = null), icon: const Icon(Icons.refresh_rounded), label: const Text('سؤال جديد')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: scheme.surface,
    );
  }

  Widget _intro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.secondaryContainer], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 27, backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary, child: const Icon(Icons.auto_awesome_rounded)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('اسأل NUS', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 5), const Text('إجابة مالية عملية مبنية على أرقام بيتك الحالية، مع ترتيب الأولويات بدل الكلام العام.')]))
      ]),
    );
  }

  Widget _liveContext(BuildContext context, FinancialSnapshot financial) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 18, runSpacing: 10, children: [
            _contextMetric('الدخل', _money(financial.monthlyIncome), Icons.arrow_downward_rounded),
            _contextMetric('التزامات', _money(financial.monthlyObligations), Icons.lock_outline_rounded),
            _contextMetric('المصروف الفعلي', _minorMoney(financial.actualExpensesMinorUnits), Icons.payments_outlined),
          ]),
        ),
      );

  Widget _contextMetric(String title, String value, IconData icon) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18), const SizedBox(width: 6), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])]);

  Widget _errorCard(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline_rounded), const SizedBox(width: 10), Expanded(child: Text('لم نقدرش نجيب الإجابة دلوقتي. جرّب نفس السؤال بعد لحظات.\n\n$_error', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)))])));

  Widget _answerCard(BuildContext context, AiInsight answer) => Column(children: [
        Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.insights_rounded), SizedBox(width: 8), Text('الخلاصة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]), const SizedBox(height: 10), Text(answer.summary, style: const TextStyle(fontSize: 17, height: 1.55, fontWeight: FontWeight.w700))])),
        if (answer.facts.isNotEmpty) ...[const SizedBox(height: 10), _sectionCard(context, 'البيانات التي بُني عليها الرد', answer.facts, Icons.fact_check_outlined)],
        if (answer.advice.isNotEmpty) ...[const SizedBox(height: 10), _sectionCard(context, 'ماذا تفعل الآن؟', answer.advice, Icons.flag_rounded)],
        if (answer.warnings.isNotEmpty) ...[const SizedBox(height: 10), _sectionCard(context, 'انتبه', answer.warnings, Icons.warning_amber_rounded)],
      ]);

  Widget _sectionCard(BuildContext context, String title, List<String> items, IconData icon) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)))]), const SizedBox(height: 10), for (var index = 0; index < items.length; index++) ...[Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle), child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900))), const SizedBox(width: 10), Expanded(child: Text(items[index], style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)))]), if (index != items.length - 1) const Divider(height: 20)]])));
}
