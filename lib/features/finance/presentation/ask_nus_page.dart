import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';

class AskNusPage extends StatefulWidget {
  const AskNusPage({
    super.key,
    required this.snapshot,
    this.provider = const FinancialAdvisorProvider(),
    this.initialQuestion,
  });

  final FinancialAdvisorSnapshot snapshot;
  final AiInsightProvider provider;
  final String? initialQuestion;

  @override
  State<AskNusPage> createState() => _AskNusPageState();
}

class _AskNusPageState extends State<AskNusPage> {
  static const List<String> _suggestedQuestions = <String>[
    'فين أكبر فرصة أوفر منها هذا الشهر؟',
    'إيه أهم خطوة مالية آمنة أعملها دلوقتي؟',
    'هل مصروفاتي الحالية مناسبة لدخلي؟',
    'إزاي أتعامل مع الالتزامات قبل أي قرار جديد؟',
  ];

  final TextEditingController _controller = TextEditingController();
  AiInsight? _answer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuestion?.trim() ?? '';
    if (initial.isNotEmpty) {
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
    FocusScope.of(context).unfocus();
    _controller.text = text;
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });
    try {
      final base = widget.snapshot.toAiRequest();
      final insight = await widget.provider.generateInsight(
        AiInsightRequest(
          objective: '${base.objective}\n'
              'سؤال المستخدم: $text\n'
              'أجب بالعربية المصرية في بنية عملية واضحة. ابدأ بالخلاصة، ثم حقائق مختصرة، ثم أولويات تنفيذية، ثم تحذيرات فقط عند الحاجة. '
              'استخدم الحقائق المرسلة فقط. لا تخترع أرقامًا أو اتجاهات أو وعودًا، ولا تذكر اسم مزود الذكاء الاصطناعي.',
          context: base.context,
        ),
      );
      if (!mounted) return;
      setState(() {
        _answer = insight;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _moneyMajor(int value) => '${_format(value)} ${widget.snapshot.financial.currencyCode}';

  String _moneyMinor(int value) {
    final metadata = CurrencyRegistry.get(widget.snapshot.financial.currencyCode);
    if (metadata.exponent == 0) return '${_format(value)} ${metadata.code}';
    final absolute = value.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    return '${value < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final raw = value.abs().toString();
    final chunks = <String>[];
    for (int i = raw.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      chunks.insert(0, raw.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  double _ratio(int numerator, int denominator) {
    if (denominator <= 0) return 0;
    return (numerator / denominator).clamp(0.0, 1.0);
  }

  String _statusTitle(FinancialSnapshot financial) {
    if (financial.monthlyIncome <= 0) return 'أدخل دخلك أولًا';
    if (financial.actualPositionMinorUnits < 0) return 'فيه ضغط نقدي هذا الشهر';
    final obligationRatio = financial.monthlyObligations / financial.monthlyIncome;
    if (obligationRatio >= .5) return 'الالتزامات محتاجة حذر';
    return 'الوضع الحالي يسمح بقرارات أهدى';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final financial = widget.snapshot.financial;
    final incomeMinor = financial.monthlyIncomeMinorUnits;
    final expenseRatio = _ratio(financial.actualExpensesMinorUnits, incomeMinor);
    final obligationRatio = _ratio(financial.monthlyObligationsMinorUnits, incomeMinor);
    final recurringRatio = _ratio(financial.expectedRecurringExpensesMinorUnits, incomeMinor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('اسأل NUS', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 34),
          children: <Widget>[
            _heroCard(context, financial),
            const SizedBox(height: 12),
            _factsCard(context, financial, expenseRatio, obligationRatio, recurringRatio),
            const SizedBox(height: 12),
            Text('اختار السؤال الأسرع', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions.map((item) => ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(item),
                onPressed: _loading ? null : () => _ask(item),
              )).toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'اكتب سؤالك لـ NUS',
                hintText: 'مثال: هل أقدر ألتزم بقسط جديد الشهر ده؟',
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _ask,
                  icon: const Icon(Icons.arrow_upward_rounded),
                  tooltip: 'اسأل NUS',
                ),
              ),
            ),
            if (_loading) ...<Widget>[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: const <Widget>[
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    SizedBox(width: 12),
                    Expanded(child: Text('NUS يرتب الحقائق ويحوّلها لأولويات عملية…', style: TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text('لم نقدرش نجهز الرد الآن', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onErrorContainer)),
                    const SizedBox(height: 6),
                    Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: _loading ? null : _ask, icon: const Icon(Icons.refresh_rounded), label: const Text('حاول مرة تانية')),
                  ]),
                ),
              ),
            ],
            if (_answer != null) ...<Widget>[
              const SizedBox(height: 14),
              _answerHero(context, _answer!),
              if (_answer!.facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _structuredListCard(context, 'الحقائق المستخدمة', _answer!.facts, Icons.dataset_rounded),
              ],
              if (_answer!.advice.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _structuredListCard(context, 'أولويات التنفيذ', _answer!.advice, Icons.bolt_rounded),
              ],
              if (_answer!.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _structuredListCard(context, 'ملاحظات مهمة', _answer!.warnings, Icons.shield_outlined),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, FinancialSnapshot financial) {
    final scheme = Theme.of(context).colorScheme;
    final positive = financial.actualPositionMinorUnits >= 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            scheme.primary,
            scheme.primaryContainer,
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(blurRadius: 28, offset: Offset(0, 14), color: Color(0x22000000)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.onPrimary.withValues(alpha: .12)),
            child: Icon(Icons.auto_awesome_rounded, color: scheme.onPrimary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('اسأل NUS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: scheme.onPrimary))),
        ]),
        const SizedBox(height: 14),
        Text(_statusTitle(financial), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: scheme.onPrimary)),
        const SizedBox(height: 7),
        Text('الرد مبني على الأرقام الفعلية الموجودة في بيتك لهذا الشهر، من غير افتراضات مخفية.', style: TextStyle(height: 1.45, color: scheme.onPrimary.withValues(alpha: .9))),
        const SizedBox(height: 16),
        Row(children: <Widget>[
          Expanded(child: _heroMetric('المتبقي الفعلي', _moneyMinor(financial.actualPositionMinorUnits), positive)),
          const SizedBox(width: 10),
          Expanded(child: _heroMetric('بعد الالتزامات', _moneyMajor(financial.positionAfterObligations), true)),
        ]),
      ]),
    );
  }

  Widget _heroMetric(String label, String value, bool ok) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: .11),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Icon(ok ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 17, color: Colors.white),
        const SizedBox(width: 4),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 5),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _factsCard(BuildContext context, FinancialSnapshot financial, double expenseRatio, double obligationRatio, double recurringRatio) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('لقطة مالية في ثانية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('النسب التالية مقارنة بالدخل الشهري المسجل، وليست تقديرات للسوق.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 14),
          _bar(context, 'المصروف الفعلي', expenseRatio, Colors.teal, _moneyMinor(financial.actualExpensesMinorUnits)),
          const SizedBox(height: 12),
          _bar(context, 'الالتزامات', obligationRatio, Colors.orange, _moneyMajor(financial.monthlyObligations)),
          const SizedBox(height: 12),
          _bar(context, 'المتكرر المتوقع', recurringRatio, Colors.purple, _moneyMinor(financial.expectedRecurringExpensesMinorUnits)),
        ]),
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double value, Color color, String amount) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text('${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text(amount, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Stack(children: <Widget>[
        Container(height: 13, decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: Theme.of(context).colorScheme.surfaceContainerHighest)),
        FractionallySizedBox(
          widthFactor: value,
          child: Container(
            height: 13,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: LinearGradient(colors: <Color>[color.withValues(alpha: .55), color]),
              boxShadow: <BoxShadow>[BoxShadow(color: color.withValues(alpha: .28), blurRadius: 7, offset: const Offset(0, 3))],
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _answerHero(BuildContext context, AiInsight answer) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Icon(Icons.flag_circle_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: 8),
            Text('الخلاصة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: scheme.onTertiaryContainer)),
          ]),
          const SizedBox(height: 8),
          Text(answer.summary, style: TextStyle(height: 1.55, fontWeight: FontWeight.w700, color: scheme.onTertiaryContainer)),
        ]),
      ),
    );
  }

  Widget _structuredListCard(BuildContext context, String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[Icon(icon), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))]),
          const SizedBox(height: 8),
          ...List<Widget>.generate(items.length, (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer),
                child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onPrimaryContainer)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(items[index], style: const TextStyle(height: 1.45))),
            ]),
          )),
        ]),
      ),
    );
  }
}
