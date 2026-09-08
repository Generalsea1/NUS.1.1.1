import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../../core/diagnostics/financial_advisor_diagnostics.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';

class FinancialAdvisorPage extends StatefulWidget {
  const FinancialAdvisorPage({
    super.key,
    required this.snapshot,
    this.provider = const FinancialAdvisorProvider(),
  });

  final FinancialAdvisorSnapshot snapshot;
  final AiInsightProvider provider;

  @override
  State<FinancialAdvisorPage> createState() => _FinancialAdvisorPageState();
}

class _FinancialAdvisorPageState extends State<FinancialAdvisorPage> {
  final _questionController = TextEditingController();
  String? _answer;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _answer = null;
      _error = null;
    });
    try {
      final request = widget.snapshot.toAiRequest();
      final insight = await widget.provider.generateInsight(
        AiInsightRequest(
          objective:
              '${request.objective}\nUser question: $question\nAnswer in clear Egyptian Arabic. Separate FACTS from ADVICE.',
          context: request.context,
        ),
      );
      if (!mounted) return;
      setState(() {
        _answer = insight.summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final financial = widget.snapshot.financial;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستشار المالي بالذكاء الاصطناعي'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إيه اللي المستشار يعرفه؟',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text('دخل الشهر، الالتزامات، المصروفات الفعلية، المصروفات المتكررة المتوقعة، والمركز المالي من Financial Engine فقط.'),
                    const SizedBox(height: 8),
                    const Text('المستشار لا يعدّل أي سجل مالي ولا ينفّذ أي إجراء.'),
                    const SizedBox(height: 14),
                    _fact('الشهر', '${financial.month.toString().padLeft(2, '0')}/${financial.year}'),
                    _fact('العملة', financial.currencyCode),
                    _fact('الدخل', '${financial.monthlyIncome} ${financial.currencyCode}'),
                    _fact('الالتزامات', '${financial.monthlyObligations} ${financial.currencyCode}'),
                    _fact('المصروفات الفعلية', '${financial.actualExpensesMinorUnits} minor units'),
                    _fact('المتكرر المتوقع', '${financial.expectedRecurringExpensesMinorUnits} minor units'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const ValueKey<String>('developer-diagnostics-button'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FinancialAdvisorDiagnosticsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.developer_mode_rounded),
              label: const Text('DEVELOPER DIAGNOSTICS'),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey<String>('advisor-question-input'),
              controller: _questionController,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _ask(),
              decoration: const InputDecoration(
                labelText: 'اسأل المستشار',
                hintText: 'مثال: أين يذهب معظم إنفاقي؟',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey<String>('advisor-ask-button'),
              onPressed: _loading ? null : _ask,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('اسأل الآن'),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('المستشار بيجهّز الرد...'),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Card(
                key: const ValueKey<String>('advisor-error-state'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('المستشار غير متاح حاليًا.'),
                      const SizedBox(height: 6),
                      Text(_error!),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _ask,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_answer == null)
              const Card(
                key: ValueKey<String>('advisor-empty-state'),
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('اكتب سؤالك. المستشار هيستخدم أرقام الشهر المحددة فقط.'),
                ),
              )
            else
              Card(
                key: const ValueKey<String>('advisor-response-state'),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رد المستشار', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(_answer!),
                      const SizedBox(height: 10),
                      const Text('الرقم المالي مصدره Financial Engine؛ النص وحده لا يغيّر أي بيانات.'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
}
