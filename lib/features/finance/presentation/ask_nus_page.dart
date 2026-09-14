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
  final TextEditingController _controller = TextEditingController();
  AiInsight? _answer;
  bool _loading = false;
  String? _error;

  static const List<String> _suggestedQuestions = <String>[
    'أين يذهب معظم إنفاقي هذا الشهر؟',
    'ما أول شيء أحتاج أن أعمله لتحسين وضعي المالي؟',
    'هل إنفاقي الحالي أعلى من قدرتي الآمنة؟',
    'كيف أتعامل مع الالتزامات قبل باقي المصروفات؟',
  ];

  @override
  void initState() {
    super.initState();
    final String? initial = widget.initialQuestion?.trim();
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
    final String text = (question ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    _controller.text = text;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });

    try {
      final AiInsightRequest request = widget.snapshot.toAiRequest();
      final AiInsight insight = await widget.provider.generateInsight(
        AiInsightRequest(
          objective: '${request.objective}\nUser question: $text\n'
              'Answer in clear Egyptian Arabic. Give a concise prioritized recommendation. '
              'Use only supplied facts.',
          context: request.context,
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

  String _money(int value) => '${_format(value)} ${widget.snapshot.financial.currencyCode}';

  String _minorMoney(int minorUnits) {
    final CurrencyMetadata metadata = CurrencyRegistry.get(
      widget.snapshot.financial.currencyCode,
    );
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final int absolute = minorUnits.abs();
    final int whole = absolute ~/ metadata.scale;
    final String fraction = (absolute % metadata.scale)
        .toString()
        .padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final String raw = value.abs().toString();
    final List<String> chunks = <String>[];
    for (int index = raw.length; index > 0; index -= 3) {
      final int start = index > 3 ? index - 3 : 0;
      chunks.insert(0, raw.substring(start, index));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final FinancialSnapshot financial = widget.snapshot.financial;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اسأل NUS', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: <Widget>[
            _buildIntro(context),
            const SizedBox(height: 14),
            _buildContext(context, financial),
            const SizedBox(height: 14),
            Text(
              'جرّب سؤالًا',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions
                  .map(
                    (String item) => ActionChip(
                      label: Text(item),
                      onPressed: _loading ? null : () => _ask(item),
                    ),
                  )
                  .toList(growable: false),
            ),
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
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _controller.clear,
                  icon: const Icon(Icons.clear_rounded),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? 'NUS بيحلل الأرقام…' : 'اسأل NUS'),
            ),
            const SizedBox(height: 16),
            if (_error != null) _buildError(context),
            if (_answer != null) _buildAnswer(context, _answer!),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 27,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'اسأل NUS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'إجابة مالية عملية مبنية على أرقام بيتك الحالية، مع ترتيب الأولويات بدل الكلام العام.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContext(BuildContext context, FinancialSnapshot financial) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: <Widget>[
            _contextMetric('الدخل', _money(financial.monthlyIncome), Icons.arrow_downward_rounded),
            _contextMetric('التزامات', _money(financial.monthlyObligations), Icons.lock_outline_rounded),
            _contextMetric('المصروف الفعلي', _minorMoney(financial.actualExpensesMinorUnits), Icons.payments_outlined),
          ],
        ),
      ),
    );
  }

  Widget _contextMetric(String title, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لم نقدرش نجيب الإجابة دلوقتي. جرّب نفس السؤال بعد لحظات.\n\n$_error',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswer(BuildContext context, AiInsight answer) {
    return Column(
      children: <Widget>[
        _responseCard(context, 'الخلاصة', answer.summary, Icons.insights_rounded),
        if (answer.facts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _listCard(context, 'البيانات التي بُني عليها الرد', answer.facts, Icons.fact_check_outlined),
        ],
        if (answer.advice.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _listCard(context, 'ماذا تفعل الآن؟', answer.advice, Icons.flag_rounded),
        ],
        if (answer.warnings.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _listCard(context, 'انتبه', answer.warnings, Icons.warning_amber_rounded),
        ],
      ],
    );
  }

  Widget _responseCard(BuildContext context, String title, String text, IconData icon) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 17, height: 1.55, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _listCard(BuildContext context, String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
              ],
            ),
            const SizedBox(height: 10),
            for (int index = 0; index < items.length; index++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(items[index], style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600))),
                ],
              ),
              if (index != items.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
