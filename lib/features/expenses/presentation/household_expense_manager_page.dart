import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/expense_lifecycle_service.dart';
import '../application/household_budget_ai_provider.dart';
import '../domain/household_budget_actual_comparison.dart';
import '../domain/household_budget_ai_recommendation.dart';
import '../domain/household_budget_management.dart';
import '../domain/household_budget_plan.dart';
import 'expense_page.dart';
import '../../ai/presentation/ai_settings_page.dart';

class HouseholdExpenseManagerPage extends StatefulWidget {
  const HouseholdExpenseManagerPage({
    super.key,
    required this.service,
    this.isArabic = true,
  });

  final ExpenseLifecycleService service;
  final bool isArabic;

  @override
  State<HouseholdExpenseManagerPage> createState() => _HouseholdExpenseManagerPageState();
}

class _HouseholdExpenseManagerPageState extends State<HouseholdExpenseManagerPage> {
  static const _storageKey = 'nus.household_budget.v2';
  static const _fields = <String, String>{
    'income': 'الدخل الشهري',
    'rent': 'السكن / الإيجار',
    'utilities': 'المرافق والفواتير',
    'food': 'الغذاء واحتياجات البيت',
    'transport': 'المواصلات / السيارة',
    'debt': 'الديون والأقساط',
    'health': 'الصحة والدواء',
    'clothing': 'الملابس',
    'maintenance': 'الصيانة والإصلاحات',
    'familyFun': 'الفسحة والعائلة',
    'other': 'متفرقات',
    'savingsTarget': 'هدف الأمان المالي',
  };

  static const _essentialKeys = <String>['rent', 'utilities', 'food', 'transport', 'debt', 'health'];
  static const _flexibleKeys = <String>['clothing', 'maintenance', 'familyFun', 'other'];

  final Map<String, TextEditingController> _controllers = {};
  final HouseholdBudgetAiProvider _aiProvider = const HouseholdBudgetAiProvider();
  HouseholdBudgetAiRecommendation? _aiRecommendation;
  HouseholdBudgetPlan? _plan;
  int _actualThisMonth = 0;
  bool _loading = true;
  bool _aiLoading = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    for (final key in _fields.keys) {
      _controllers[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _fields.keys) {
      final saved = prefs.getInt('$_storageKey.$key');
      _controllers[key]!.text = saved == null || saved == 0 ? '' : saved.toString();
    }

    try {
      final expenses = await widget.service.list();
      final now = DateTime.now();
      _actualThisMonth = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month && e.amount.currencyCode == 'EGP')
          .fold<int>(0, (sum, e) => sum + e.amount.minorUnits ~/ 100);
    } catch (_) {
      _actualThisMonth = 0;
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _plan = _buildPlan();
    });
  }

  int _value(String key) => int.tryParse(_controllers[key]!.text.trim()) ?? 0;

  HouseholdBudgetInput _input() => HouseholdBudgetInput(
        monthlyIncome: _value('income'),
        rent: _value('rent'),
        utilities: _value('utilities'),
        food: _value('food'),
        transport: _value('transport'),
        debt: _value('debt'),
        health: _value('health'),
        clothing: _value('clothing'),
        maintenance: _value('maintenance'),
        familyFun: _value('familyFun'),
        other: _value('other'),
        savingsTarget: _value('savingsTarget'),
        aiRecommendation: _aiRecommendation,
      );

  HouseholdBudgetPlan _buildPlan() => buildHouseholdBudgetPlan(_input());

  HouseholdBudgetActualComparison _actualComparison(HouseholdBudgetPlan plan) {
    final plannedSpending = (plan.plannedTotal - plan.reserve).clamp(0, 0x7fffffffffffffff);
    return HouseholdBudgetActualComparison(
      plannedAmount: plannedSpending,
      actualAmount: _actualThisMonth,
    );
  }

  Future<void> _buildWithAi() async {
    if (_aiLoading) return;
    final income = _value('income');
    if (income <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Enter your monthly income first.', 'اكتب الدخل الشهري الأول عشان مدير البيت يبدأ.'))),
      );
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiRecommendation = null;
      _plan = _buildPlan();
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _fields.keys) {
        await prefs.setInt('$_storageKey.$key', _value(key));
      }

      final recommendation = await _aiProvider.generate(
        input: _input(),
        actualThisMonth: _actualThisMonth,
      );

      if (!mounted) return;
      setState(() {
        _aiRecommendation = recommendation;
        _plan = _buildPlan();
        _aiLoading = false;
      });
    } on HouseholdBudgetAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiError = error.message;
        _plan = _buildPlan();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiLoading = false;
        _aiError = _t('Unexpected AI service error.', 'حصل خطأ غير متوقع في خدمة الذكاء الاصطناعي.');
        _plan = _buildPlan();
      });
    }
  }

  String _money(int amount) => '${_formatNumber(amount)} ${_t('EGP', 'جنيه')}';

  String _formatNumber(int value) {
    final text = value.abs().toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${parts.join(',')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final plan = _plan ?? _buildPlan();
    final comparison = _actualComparison(plan);

    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E5A4F),
      brightness: base.brightness,
    );
    final theme = base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: base.brightness == Brightness.dark
          ? const Color(0xFF0B1412)
          : const Color(0xFFF5F1E8),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );

    return Theme(
      data: theme,
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('Household Manager', 'مدير اقتصاد البيت'), style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: _t('AI connection', 'اتصال الذكاء الاصطناعي'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: widget.isArabic)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
              IconButton(
                tooltip: _t('Expense ledger', 'سجل المصروفات'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ExpensePage(service: widget.service, isArabic: widget.isArabic)),
                ),
                icon: const Icon(Icons.receipt_long_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _managerHero(plan),
              const SizedBox(height: 14),
              _commandStrip(plan),
              const SizedBox(height: 14),
              _actualCard(comparison),
              const SizedBox(height: 14),
              if (_aiError != null) ...[
                _errorCard(_aiError!),
                const SizedBox(height: 14),
              ],
              if (plan.isAiPowered) ...[
                _aiDecisionCard(plan),
                const SizedBox(height: 14),
              ],
              _inputSection(
                title: _t('Foundation', 'أساس البيت'),
                subtitle: _t('Protect these before lifestyle spending.', 'دي البنود اللي بنحميها الأول قبل أي رفاهية.'),
                keys: _essentialKeys,
              ),
              const SizedBox(height: 14),
              _inputSection(
                title: _t('Lifestyle & flexibility', 'المرونة وأسلوب الحياة'),
                subtitle: _t('These are the first places to trim when money gets tight.', 'دي أول مناطق التخفيض لما الدخل يضغط.'),
                keys: _flexibleKeys,
              ),
              const SizedBox(height: 14),
              _inputSection(
                title: _t('Financial safety', 'الأمان المالي'),
                subtitle: _t('Build a buffer instead of spending every pound.', 'مش لازم نصرف كل جنيه متبقي؛ الأمان المالي جزء من الخطة.'),
                keys: const ['savingsTarget'],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _aiLoading ? null : _buildWithAi,
                icon: _aiLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Text(
                    _aiLoading
                        ? _t('AI is managing your month…', 'مدير البيت الذكي بيبني الخطة…')
                        : _t('Build my household plan with AI', 'ابنِ لي خطة البيت بالذكاء الاصطناعي'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _managementCard(plan.management),
              const SizedBox(height: 14),
              _statusCard(plan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _managerHero(HouseholdBudgetPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final income = plan.input.monthlyIncome;
    final free = plan.remaining;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, const Color(0xFF143D36)],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE6C98B).withValues(alpha: .18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE6C98B).withValues(alpha: .45)),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFE6C98B)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _t('HOUSEHOLD ECONOMY', 'اقتصاد البيت'),
                  style: const TextStyle(color: Color(0xFFE6C98B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                const SizedBox(height: 3),
                Text(
                  _t('Your money needs a manager, not a ledger.', 'فلوس البيت محتاجة مدير اقتصادي، مش مجرد دفتر مصروفات.'),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.15),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Text(
            income > 0 ? _money(income) : _t('Enter your monthly income', 'اكتب الدخل الشهري'),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            income > 0
                ? _t('planned income • ${_money(free)} flexible room', 'دخل الخطة • ${_money(free)} مساحة حركة')
                : _t('The manager starts from a real income number.', 'المدير الاقتصادي لازم يبدأ من رقم دخل حقيقي.'),
            style: TextStyle(color: Colors.white.withValues(alpha: .78), fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  Widget _commandStrip(HouseholdBudgetPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    final protectedRatio = plan.input.monthlyIncome <= 0
        ? 0.0
        : (plan.input.mandatoryTotal / plan.input.monthlyIncome).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.speed_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(_t('Manager cockpit', 'لوحة قرار مدير البيت'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            _pill(plan.isAiPowered ? _t('AI ACTIVE', 'AI شغّال') : _t('READY', 'جاهز')),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: protectedRatio, minHeight: 9),
          ),
          const SizedBox(height: 8),
          Text(
            _t('Protected commitments use ${(protectedRatio * 100).round()}% of income.', 'الالتزامات الأساسية بتستهلك ${(protectedRatio * 100).round()}% من الدخل.'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _miniMetric(_t('Essentials', 'الأساسيات'), _money(plan.input.mandatoryTotal), Icons.shield_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _miniMetric(_t('Weekly ceiling', 'سقف الأسبوع'), _money(plan.weeklyAllowance), Icons.date_range_rounded)),
          ]),
        ]),
      ),
    );
  }

  Widget _actualCard(HouseholdBudgetActualComparison comparison) {
    final scheme = Theme.of(context).colorScheme;
    final over = comparison.isOverPlan;
    return Card(
      color: over ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(over ? Icons.warning_amber_rounded : Icons.verified_outlined),
            const SizedBox(width: 8),
            Text(_t('Reality check', 'مراجعة الواقع'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _miniMetric(_t('Plan', 'الخطة'), _money(comparison.plannedAmount), Icons.flag_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _miniMetric(_t('Actual', 'الفعلي'), _money(comparison.actualAmount), Icons.receipt_long_outlined)),
          ]),
          const SizedBox(height: 8),
          Text(comparison.managerMessage, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
        ]),
      ),
    );
  }

  Widget _aiDecisionCard(HouseholdBudgetPlan plan) {
    final recommendation = _aiRecommendation!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded),
            const SizedBox(width: 8),
            Expanded(child: Text(_t('AI decision', 'قرار مدير البيت الذكي'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            _pill(_t('VERIFIED', 'مُراجع')),
          ]),
          const SizedBox(height: 10),
          Text(recommendation.managerMessage, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
          const SizedBox(height: 10),
          Text(recommendation.recommendation, style: const TextStyle(height: 1.45)),
        ]),
      ),
    );
  }

  Widget _inputSection({required String title, required String subtitle, required List<String> keys}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 5, height: 26, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8))),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 12),
          ...keys.map((key) => _field(key)),
        ]),
      ),
    );
  }

  Widget _field(String key) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _controllers[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          onChanged: (_) => setState(() {
            _aiRecommendation = null;
            _aiError = null;
            _plan = _buildPlan();
          }),
          decoration: InputDecoration(
            labelText: _fields[key],
            suffixText: _t('EGP', 'جنيه'),
            prefixIcon: Icon(_iconFor(key)),
            filled: true,
          ),
        ),
      );

  Widget _managementCard(HouseholdBudgetManagement management) {
    final labels = <HouseholdBudgetPriority, String>{
      HouseholdBudgetPriority.essential: _t('Essential', 'أساسي'),
      HouseholdBudgetPriority.important: _t('Important', 'مهم'),
      HouseholdBudgetPriority.flexible: _t('Flexible', 'مرن'),
      HouseholdBudgetPriority.reserve: _t('Reserve', 'احتياطي'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('Manager instructions', 'تعليمات مدير البيت'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(management.managerMessage, style: const TextStyle(height: 1.45)),
          const Divider(height: 26),
          ...management.lines.map((line) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_priorityIcon(line.priority)),
                title: Text(line.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${labels[line.priority]}${line.autoAllocated ? ' • ${_t('AI estimate', 'تقدير المدير')}' : ''}'),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_money(line.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                  if (line.weeklyCap > 0) Text('${_money(line.weeklyCap)} / ${_t('week', 'أسبوع')}', style: const TextStyle(fontSize: 11)),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _statusCard(HouseholdBudgetPlan plan) {
    final title = switch (plan.status) {
      BudgetStatus.healthy => _t('Healthy plan', 'الخطة متوازنة'),
      BudgetStatus.tight => _t('Tight month', 'الشهر محتاج حذر'),
      BudgetStatus.overBudget => _t('Over budget', 'الخطة أعلى من الدخل'),
      BudgetStatus.incomplete => _t('Needs more information', 'الخطة محتاجة بيانات'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(plan.recommendation, style: const TextStyle(height: 1.45)),
          const Divider(height: 26),
          Row(children: [
            const Icon(Icons.savings_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(_t('Safety reserve', 'احتياطي الأمان'), style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(_money(plan.reserve), style: const TextStyle(fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
    );
  }

  Widget _errorCard(String message) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))),
          ]),
        ),
      );

  Widget _miniMetric(String title, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            FittedBox(alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ])),
        ]),
      );

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)),
      );

  IconData _iconFor(String key) {
    switch (key) {
      case 'income': return Icons.payments_rounded;
      case 'rent': return Icons.home_work_outlined;
      case 'utilities': return Icons.bolt_rounded;
      case 'food': return Icons.shopping_basket_outlined;
      case 'transport': return Icons.directions_car_outlined;
      case 'debt': return Icons.account_balance_outlined;
      case 'health': return Icons.health_and_safety_outlined;
      case 'clothing': return Icons.checkroom_outlined;
      case 'maintenance': return Icons.build_outlined;
      case 'familyFun': return Icons.celebration_outlined;
      case 'savingsTarget': return Icons.savings_rounded;
      default: return Icons.more_horiz_rounded;
    }
  }

  IconData _priorityIcon(HouseholdBudgetPriority priority) {
    switch (priority) {
      case HouseholdBudgetPriority.essential: return Icons.shield_outlined;
      case HouseholdBudgetPriority.important: return Icons.warning_amber_rounded;
      case HouseholdBudgetPriority.flexible: return Icons.tune_rounded;
      case HouseholdBudgetPriority.reserve: return Icons.savings_outlined;
    }
  }
}
