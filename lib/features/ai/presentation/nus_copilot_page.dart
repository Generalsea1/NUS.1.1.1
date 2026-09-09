import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../../core/supabase_service.dart';
import '../../appointments/data/local_appointment_repository.dart';
import '../../appointments/domain/appointment.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../expenses/data/supabase_expense_repository.dart';
import '../../expenses/data/supabase_recurring_expense_repository.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';
import '../../household/application/household_service.dart';
import '../../household/data/supabase_household_repository.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../onboarding/data/supabase_household_profile_repository.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../shopping/data/supabase_household_shopping_repository.dart';
import '../application/nus_ai_context_composer.dart';

class NusCopilotPage extends StatefulWidget {
  const NusCopilotPage({
    super.key,
    this.provider = const FinancialAdvisorProvider(),
    this.contextBuilder,
  });

  final AiInsightProvider provider;
  final Future<AiInsightRequest> Function(String question)? contextBuilder;

  @override
  State<NusCopilotPage> createState() => _NusCopilotPageState();
}

class _NusCopilotPageState extends State<NusCopilotPage> {
  final _questionController = TextEditingController();
  HouseholdProfile? _profile;
  AiInsight? _answer;
  bool _loadingContext = true;
  bool _loadingAnswer = false;
  String? _contextError;
  String? _answerError;

  @override
  void initState() {
    super.initState();
    if (widget.contextBuilder == null) {
      _loadContext();
    } else {
      _loadingContext = false;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadContext() async {
    setState(() {
      _loadingContext = true;
      _contextError = null;
    });
    try {
      final client = SupabaseService.client;
      final userId = client?.auth.currentUser?.id.trim();
      if (userId == null || userId.isEmpty) {
        throw StateError('يجب تسجيل الدخول لاستخدام NUS Copilot.');
      }

      final profile = await const SupabaseHouseholdProfileRepository().load(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loadingContext = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _contextError = error.toString();
      });
    }
  }

  Future<AiInsightRequest> _buildRequest(String question) async {
    final profile = _profile;
    final client = SupabaseService.client;
    final userId = client?.auth.currentUser?.id.trim();
    if (profile == null || userId == null || userId.isEmpty) {
      throw StateError('بيانات الحساب والبيت غير جاهزة بعد.');
    }

    final context = <AiContextItem>[
      AiContextItem(
        domain: 'household',
        entityId: 'current-household',
        summary: 'البيت: ${profile.householdSize} أفراد، ${profile.adults} بالغين، ${profile.children} أطفال، العملة ${profile.currencyCode}.',
      ),
    ];

    try {
      final household = await HouseholdService(
        repository: const SupabaseHouseholdRepository(),
      ).getOrCreateForUser(userId: userId);
      context.add(AiContextItem(
        domain: 'household',
        entityId: 'household-space',
        summary: 'مساحة البيت الحالية: ${household.name}.',
      ));

      final shopping = await SupabaseHouseholdShoppingRepository(
        householdId: household.id,
      ).list();
      final pending = shopping.fold<int>(
        0,
        (total, list) => total + list.items.where((item) => !item.isCompleted).length,
      );
      context.add(AiContextItem(
        domain: 'shopping',
        entityId: 'pending-shopping',
        summary: 'عدد عناصر المشتريات غير المكتملة حاليًا: $pending.',
      ));
    } catch (_) {
      // Optional shared household context must never block Copilot.
    }

    try {
      final appointments = await LocalAppointmentRepository().list();
      final upcoming = appointments
          .where((item) => item.status == AppointmentStatus.upcoming)
          .where((item) => item.startsAt.isAfter(DateTime.now()))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      context.add(AiContextItem(
        domain: 'calendar',
        entityId: 'upcoming-appointments',
        summary: 'عدد المواعيد القادمة: ${upcoming.length}.${upcoming.isEmpty ? '' : ' أقرب موعد: ${upcoming.first.title} في ${upcoming.first.startsAt.toLocal()}.'}',
      ));
    } catch (_) {
      // Calendar context is optional and must never block Copilot.
    }

    try {
      final incomeService = IncomeSourceService(
        repository: const SupabaseIncomeSourceRepository(),
      );
      final obligationService = ObligationService(
        repository: const SupabaseObligationRepository(),
      );
      final expenseManagementService = ExpenseManagementService(
        expenseRepository: const SupabaseExpenseRepository(),
        recurringRepository: const SupabaseRecurringExpenseRepository(),
      );
      final engine = FinancialEngine(
        incomeService: incomeService,
        obligationService: obligationService,
        expenseService: expenseManagementService,
      );
      final now = DateTime.now();
      final snapshot = await engine.calculate(
        userId: userId,
        year: now.year,
        month: now.month,
        currencyCode: profile.currencyCode,
      );
      context.add(AiContextItem(
        domain: 'finance',
        entityId: 'current-month',
        summary: 'الشهر الحالي ${now.month}/${now.year}: الدخل ${snapshot.monthlyIncome} ${snapshot.currencyCode}، الالتزامات ${snapshot.monthlyObligations} ${snapshot.currencyCode}، المصروفات الفعلية ${snapshot.actualExpensesMinorUnits} minor units، والمتكرر المتوقع ${snapshot.expectedRecurringExpensesMinorUnits} minor units.',
      ));
    } catch (_) {
      // Financial context is optional when the backend is unavailable.
    }

    return NusAiContextComposer.compose(
      objective: 'أنت NUS Copilot. ساعد المستخدم في تنظيم حياته وبيته باستخدام الحقائق المعروضة فقط. افصل FACTS عن ADVICE. لا تخترع أرقامًا، ولا تنفذ أو تقترح تنفيذ كتابة مالية بدون تأكيد صريح. أجب بالمصرية الواضحة. سؤال المستخدم: $question',
      context: context,
      allowedDomains: const {'household', 'calendar', 'shopping', 'finance'},
      maxItems: 12,
    );
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _loadingAnswer || _loadingContext) return;
    setState(() {
      _loadingAnswer = true;
      _answer = null;
      _answerError = null;
    });
    try {
      final request = widget.contextBuilder == null
          ? await _buildRequest(question)
          : await widget.contextBuilder!(question);
      final insight = await widget.provider.generateInsight(request);
      if (!mounted) return;
      setState(() {
        _answer = insight;
        _loadingAnswer = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _answerError = error.toString();
        _loadingAnswer = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NUS Copilot', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اسأل NUS عن يومك وبيتك',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text('Copilot يقرأ سياقًا محدودًا من البيت والمواعيد والمشتريات والمال. لا يكتب أي بيانات ولا ينفذ إجراءً من تلقاء نفسه.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingContext)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Expanded(child: Text('بجهز سياق البيت…'))]),
                  ),
                )
              else if (_contextError != null)
                Card(
                  key: const ValueKey<String>('copilot-context-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(_contextError!),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(onPressed: _loadContext, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  key: const ValueKey<String>('copilot-question-input'),
                  controller: _questionController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _ask(),
                  decoration: const InputDecoration(
                    labelText: 'اسأل NUS',
                    hintText: 'مثال: إيه أهم حاجة أركز عليها النهارده؟',
                    prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey<String>('copilot-ask-button'),
                  onPressed: _loadingAnswer ? null : _ask,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('اسأل NUS'),
                ),
                const SizedBox(height: 16),
                if (_loadingAnswer)
                  const Card(
                    key: ValueKey<String>('copilot-loading'),
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('NUS بيجمع الحقائق وبيجهز الرد…')]),
                    ),
                  )
                else if (_answerError != null)
                  Card(
                    key: const ValueKey<String>('copilot-error'),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Copilot غير متاح حاليًا.'),
                          const SizedBox(height: 6),
                          Text(_answerError!),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(onPressed: _ask, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                        ],
                      ),
                    ),
                  )
                else if (_answer != null)
                  Card(
                    key: const ValueKey<String>('copilot-response'),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('رد NUS', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Text(_answer!.summary),
                          const SizedBox(height: 10),
                          Text('المحتوى مبني على سياق محدود ومصادر قراءة فقط.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
