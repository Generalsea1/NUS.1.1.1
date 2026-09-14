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
    'أين يذهب معظم إنفاقي هذا الشهر؟',
    'ما أول شيء أحتاج أن أعمله لتحسين وضعي المالي؟',
    'هل إنفاقي الحالي أعلى من قدرتي الآمنة؟',
    'كيف أتعامل مع الالتزامات قبل باقي المصروفات؟',
  ];

  final TextEditingController _controller = TextEditingController();
  AiInsight? _answer;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final String initial = widget.initialQuestion?.trim() ?? '';
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
    final String text = (question ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;

    FocusScope.of(context).unfocus();
    _controller.text = text;
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });

    try {
      final AiInsightRequest base = widget.snapshot.toAiRequest();
      final AiInsight insight = await widget.provider.generateInsight(
        AiInsightRequest(
          objective: '${base.objective}\n'
              'سؤال المستخدم: $text\n'
              'أجب بالعربية المصرية بوضوح وبترتيب عملي. استخدم الحقائق المرسلة فقط. '
              'لا تخترع أرقامًا أو اتجاهات أو وعودًا.',
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
    final CurrencyMetadata metadata = CurrencyRegistry.get(
      widget.snapshot.financial.currencyCode,
    );
    if (metadata.exponent == 0) return '${_format(value)} ${metadata.code}';
    final int absolute = value.abs();
    final int whole = absolute ~/ metadata.scale;
    final String fraction = (absolute % metadata.scale)
        .toString()
        .padLeft(metadata.exponent, '0');
    final String sign = value < 0 ? '-' : '';
    return '$sign${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final String raw = value.abs().toString();
    final List<String> chunks = <String>[];
    for (int i = raw.length; i > 0; i -= 3) {
      final int start = i > 3 ? i - 3 : 0;
      chunks.insert(0, raw.substring(start, i));
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: <Widget>[
            Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.auto_awesome_rounded, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          'اسأل NUS عن وضع بيتك',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'الرد مبني على البيانات المالية الموجودة فعلًا في NUS، وليس على أرقام افتراضية.',
                      style: TextStyle(color: scheme.onPrimaryContainer, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _fact('دخل الشهر', _moneyMajor(financial.monthlyIncome)),
                    _fact('الالتزامات', _moneyMajor(financial.monthlyObligations)),
                    _fact('المصروف الفعلي', _moneyMinor(financial.actualExpensesMinorUnits)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _ask(),
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'اكتب سؤالك',
                hintText: 'مثال: ما أول خطوة مالية آمنة أعملها اليوم؟',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _ask,
                  icon: const Icon(Icons.send_rounded),
                  tooltip: 'إرسال',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'أسئلة جاهزة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
            if (_loading) ...<Widget>[
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('NUS يراجع بياناتك الآن', style: TextStyle(fontWeight: FontWeight.w900)),
                      SizedBox(height: 10),
                      LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('تعذر الحصول على رد الآن', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onErrorContainer)),
                      const SizedBox(height: 6),
                      Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _ask,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_answer != null) ...<Widget>[
              const SizedBox(height: 16),
              _sectionCard(context, 'الخلاصة', _answer!.summary, Icons.flag_rounded),
              if (_answer!.facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _listCard(context, 'البيانات التي بُني عليها الرد', _answer!.facts, Icons.dataset_rounded),
              ],
              if (_answer!.advice.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _listCard(context, 'ماذا تفعل الآن؟', _answer!.advice, Icons.task_alt_rounded),
              ],
              if (_answer!.warnings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _listCard(context, 'انتبه', _answer!.warnings, Icons.warning_amber_rounded),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, String title, String body, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listCard(BuildContext context, String title, List<String> items, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(children: <Widget>[Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
            const SizedBox(height: 6),
            ...items.map((String item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text('• $item', style: const TextStyle(height: 1.45)),
            )),
          ],
        ),
      ),
    );
  }
}