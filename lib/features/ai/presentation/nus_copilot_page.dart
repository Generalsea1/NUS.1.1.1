import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../today/data/speech_to_text_nus_voice_input.dart';
import '../../today/domain/nus_voice_input.dart';
import '../application/financial_copilot_provider.dart';

class NusCopilotPage extends StatefulWidget {
  const NusCopilotPage({
    super.key,
    required this.profile,
    this.onCreateReminder,
    this.onOpenAppointments,
    this.onOpenFinance,
    this.voiceInput,
  });

  final HouseholdProfile profile;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenFinance;
  final NusVoiceInput? voiceInput;

  @override
  State<NusCopilotPage> createState() => _NusCopilotPageState();
}

class _NusCopilotPageState extends State<NusCopilotPage> {
  late final TextEditingController _questionController;
  late final NusVoiceInput _voiceInput;
  bool _busy = false;
  String? _error;
  AiInsight? _answer;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _voiceInput = widget.voiceInput ?? SpeechToTextNusVoiceInput();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (_busy) return;
    final text = await _voiceInput.listen(localeId: 'ar-EG');
    if (!mounted || text == null || text.trim().isEmpty) return;
    setState(() => _questionController.text = text.trim());
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });

    try {
      final provider = FinancialCopilotProvider();
      final answer = await provider.generateInsight(
        AiInsightRequest(
          objective: question,
          context: [
            AiContextItem(
              domain: 'household_profile',
              entityId: widget.profile.userId,
              summary:
                  'country=${widget.profile.countryCode}; currency=${widget.profile.currencyCode}; householdSize=${widget.profile.householdSize}; adults=${widget.profile.adults}; children=${widget.profile.children}; monthlyIncome=${widget.profile.monthlyIncome}; recurringObligations=${widget.profile.recurringObligations}; remainingAfterObligations=${widget.profile.remainingAfterObligations}',
            ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() => _answer = answer);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createReminder() async {
    final createReminder = widget.onCreateReminder;
    if (createReminder == null) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تذكير جديد'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'أعمل NUS يفكّرك بإيه؟'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('التالي')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || title == null || title.isEmpty) return;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    await createReminder(title, DateTime(picked.year, picked.month, picked.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('NUS Copilot', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('قول لـNUS أنت محتاج إيه', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text('اسأل، اختار إجراء، وبعدها NUS ينفّذ عبر الخدمات الموجودة بالفعل. التحليل المالي يظل مبنيًا على بيانات حسابك الحقيقية.'),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  TextField(
                    key: const Key('copilot-question'),
                    controller: _questionController,
                    minLines: 2,
                    maxLines: 5,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      labelText: 'اكتب سؤالك أو طلبك',
                      hintText: 'مثال: ينفع أشتري غسالة دلوقتي؟',
                      prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                      suffixIcon: IconButton(
                        key: const Key('copilot-voice'),
                        tooltip: 'إملاء صوتي',
                        onPressed: _busy ? null : _listen,
                        icon: const Icon(Icons.mic_none_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('copilot-ask'),
                      onPressed: _busy ? null : _ask,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(_busy ? 'NUS بيفكّر…' : 'اسأل NUS'),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            _actionsCard(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [Icon(Icons.insights_rounded), SizedBox(width: 8), Text('رد NUS', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))]),
                    const SizedBox(height: 12),
                    SelectableText(_answer!.summary, style: const TextStyle(height: 1.55)),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'NUS لا ينفّذ تغييرًا ماليًا أو حذفًا من خلال السؤال وحده. الإجراءات الحساسة تظل اختيارًا صريحًا من المستخدم.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('إجراءات سريعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            _action(
              icon: Icons.alarm_add_rounded,
              title: 'اعملي تذكير',
              subtitle: 'أضف تذكير عبر نفس محرك NUS الحالي.',
              onTap: _createReminder,
            ),
            _action(
              icon: Icons.event_available_rounded,
              title: 'افتح مواعيدي',
              subtitle: 'راجع أو عدّل مواعيدك.',
              onTap: widget.onOpenAppointments,
            ),
            _action(
              icon: Icons.account_balance_wallet_rounded,
              title: 'افتح فلوسي',
              subtitle: 'راجع الدخل والالتزامات والأهداف.',
              onTap: widget.onOpenFinance,
            ),
          ]),
        ),
      );

  Widget _action({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: onTap,
      );
}
