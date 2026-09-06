import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../ai/presentation/ai_settings_page.dart';
import '../../../core/supabase_service.dart';
import '../application/expense_lifecycle_service.dart';
import '../application/household_budget_ai_provider.dart';
import '../domain/household_budget_actual_comparison.dart';
import '../domain/household_budget_ai_recommendation.dart';
import '../domain/household_budget_management.dart';
import '../domain/household_budget_plan.dart';
import 'expense_page.dart';

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
  static const _storageKey = 'nus.household_budget.v3';
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
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _currencyController = TextEditingController();

  HouseholdBudgetAiRecommendation? _aiRecommendation;
  HouseholdBudgetPlan? _plan;
  int _actualThisMonth = 0;
  bool _loading = true;
  bool _savingProfile = false;
  bool _aiLoading = false;
  bool _profileSaved = false;
  String? _aiError;
  String _housingType = 'rent';
  String _incomeFrequency = 'monthly';
  int _adults = 1;
  int _children = 0;

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
    _countryController.dispose();
    _regionController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  String _t(String en, String ar) => widget.isArabic ? ar : en;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _fields.keys) {
      final saved = prefs.getInt('$_storageKey.$key');
      _controllers[key]!.text = saved == null || saved == 0 ? '' : saved.toString();
    }

    final client = SupabaseService.client;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final row = await client
            .from('household_profiles')
            .select('country_code,region,currency_code,household_size,adults,children,housing_type,income_frequency,monthly_income,recurring_debt,emergency_target,budget_snapshot')
            .eq('user_id', userId)
            .maybeSingle();
        if (row != null) {
          _countryController.text = (row['country_code'] as String? ?? '').trim();
          _regionController.text = (row['region'] as String? ?? '').trim();
          _currencyController.text = (row['currency_code'] as String? ?? '').trim();
          _adults = _safePositiveInt(row['adults'], fallback: 1);
          _children = _safeNonNegativeInt(row['children']);
          _housingType = _safeHousing(row['housing_type']);
          _incomeFrequency = _safeFrequency(row['income_frequency']);

          final monthlyIncome = _safeNonNegativeInt(row['monthly_income']);
          final recurringDebt = _safeNonNegativeInt(row['recurring_debt']);
          final emergencyTarget = _safeNonNegativeInt(row['emergency_target']);
          if (monthlyIncome > 0) _controllers['income']!.text = '$monthlyIncome';
          if (recurringDebt > 0) _controllers['debt']!.text = '$recurringDebt';
          if (emergencyTarget > 0) _controllers['savingsTarget']!.text = '$emergencyTarget';

          final snapshot = row['budget_snapshot'];
          if (snapshot is Map) {
            for (final key in _fields.keys) {
              if (key == 'income' || key == 'debt' || key == 'savingsTarget') continue;
              final value = _safeNonNegativeInt(snapshot[key]);
              if (value > 0) _controllers[key]!.text = '$value';
            }
          }
          _profileSaved = true;
        }
      } catch (_) {
        // Local data remains usable when profile retrieval is temporarily unavailable.
      }
    }

    try {
      final expenses = await widget.service.list();
      final now = DateTime.now();
      final currency = _currencyController.text.trim().toUpperCase();
      _actualThisMonth = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month && (currency.isEmpty || e.amount.currencyCode == currency))
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

  int _safeNonNegativeInt(Object? value) {
    final number = value is int ? value : int.tryParse('$value');
    return number == null || number < 0 ? 0 : number;
  }

  int _safePositiveInt(Object? value, {required int fallback}) {
    final number = _safeNonNegativeInt(value);
    return number <= 0 ? fallback : number;
  }

  String _safeHousing(Object? value) {
    const values = {'rent', 'owned', 'family', 'other'};
    final text = '$value';
    return values.contains(text) ? text : 'rent';
  }

  String _safeFrequency(Object? value) {
    const values = {'monthly', 'weekly', 'biweekly', 'irregular'};
    final text = '$value';
    return values.contains(text) ? text : 'monthly';
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
        providedFields: _fields.keys
            .where((key) => key != 'income' && _controllers[key]!.text.trim().isNotEmpty)
            .toSet(),
        aiRecommendation: _aiRecommendation,
      );

  HouseholdBudgetPlan _buildPlan() => buildHouseholdBudgetPlan(_input());

  HouseholdBudgetActualComparison _actualComparison(HouseholdBudgetPlan plan) {
    final plannedSpending = (plan.plannedTotal - plan.reserve).clamp(0, 0x7fffffffffffffff);
    return HouseholdBudgetActualComparison(plannedAmount: plannedSpending, actualAmount: _actualThisMonth);
  }

  Future<bool> _saveProfile() async {
    final client = SupabaseService.client;
    final userId = client?.auth.currentUser?.id;
    final country = _countryController.text.trim().toUpperCase();
    final currency = _currencyController.text.trim().toUpperCase();
    final income = _value('income');
    if (client == null || userId == null) {
      _showMessage(_t('Sign in to save your household profile.', 'سجّل الدخول الأول عشان بيانات الأسرة تتحفظ على حسابك.'));
      return false;
    }
    if (country.length != 2 || currency.length < 3 || income <= 0) {
      _showMessage(_t('Enter country, currency and real monthly income first.', 'اكتب الدولة والعملة والدخل الشهري الحقيقي الأول.'));
      return false;
    }

    setState(() => _savingProfile = true);
    try {
      await client.from('household_profiles').upsert({
        'user_id': userId,
        'country_code': country,
        'region': _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
        'currency_code': currency,
        'household_size': _adults + _children,
        'adults': _adults,
        'children': _children,
        'housing_type': _housingType,
        'income_frequency': _incomeFrequency,
        'monthly_income': income,
        'recurring_debt': _value('debt'),
        'emergency_target': _value('savingsTarget'),
        'budget_snapshot': {
          for (final key in _fields.keys) key: _value(key),
          'providedFields': _input().providedFields.toList(growable: false),
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final prefs = await SharedPreferences.getInstance();
      for (final key in _fields.keys) {
        await prefs.setInt('$_storageKey.$key', _value(key));
      }
      if (!mounted) return true;
      setState(() => _profileSaved = true);
      return true;
    } on PostgrestException catch (error) {
      _showMessage(error.message);
      return false;
    } catch (_) {
      _showMessage(_t('Could not save the household profile.', 'ماقدرتش أحفظ بيانات الأسرة دلوقتي.'));
      return false;
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _buildWithAi() async {
    if (_aiLoading) return;
    if (!await _saveProfile()) return;

    setState(() {
      _aiLoading = true;
      _aiError = null;
      _aiRecommendation = null;
      _plan = _buildPlan();
    });

    try {
      final recommendation = await _aiProvider.generate(input: _input(), actualThisMonth: _actualThisMonth);
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(int amount) {
    final code = _currencyController.text.trim().toUpperCase();
    final suffix = code.isEmpty ? _t('currency', 'العملة') : code;
    return '${_formatNumber(amount)} $suffix';
  }

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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final plan = _plan ?? _buildPlan();
    final comparison = _actualComparison(plan);
    final base = Theme.of(context);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0E5A4F), brightness: base.brightness);
    final theme = base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: base.brightness == Brightness.dark ? const Color(0xFF0B1412) : const Color(0xFFF5F1E8),
      cardTheme: CardThemeData(margin: EdgeInsets.zero, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    );

    return Theme(
      data: theme,
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('Household Manager', 'مدير اقتصاد الأسرة'), style: const TextStyle(fontWeight: FontWeight.w900)),
            actions: [
              IconButton(tooltip: _t('AI connection', 'اتصال الذكاء الاصطناعي'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: widget.isArabic))), icon: const Icon(Icons.auto_awesome_rounded)),
              IconButton(tooltip: _t('Expense ledger', 'سجل المصروفات'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpensePage(service: widget.service, isArabic: widget.isArabic))), icon: const Icon(Icons.receipt_long_rounded)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _hero(plan),
              const SizedBox(height: 14),
              _profileCard(),
              const SizedBox(height: 14),
              _actualCard(comparison),
              const SizedBox(height: 14),
              if (_aiError != null) ...[_errorCard(_aiError!), const SizedBox(height: 14)],
              if (plan.isAiPowered) ...[_aiDecisionCard(), const SizedBox(height: 14)],
              _inputSection(title: _t('Foundation', 'أساس البيت'), subtitle: _t('Protect these first. They are not lifestyle extras.', 'دي أول بنود الحماية، مش كماليات.'), keys: _essentialKeys),
              const SizedBox(height: 14),
              _inputSection(title: _t('Lifestyle & flexibility', 'المرونة وأسلوب الحياة'), subtitle: _t('Trim these first when the month is tight.', 'دي أول مساحة للتخفيض وقت الضغط.'), keys: _flexibleKeys),
              const SizedBox(height: 14),
              _inputSection(title: _t('Financial safety', 'الأمان المالي'), subtitle: _t('A reserve is part of managing the household, not leftover spending.', 'الاحتياطي جزء من الإدارة، مش فلوس فائضة لازم تتصرف.'), keys: const ['savingsTarget']),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _aiLoading || _savingProfile ? null : _buildWithAi,
                icon: _aiLoading || _savingProfile ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                label: Padding(padding: const EdgeInsets.symmetric(vertical: 15), child: Text(_aiLoading ? _t('AI is managing your month…', 'مدير البيت الذكي بيبني الخطة…') : _t('Build my household plan with AI', 'ابنِ لي خطة البيت بالذكاء الاصطناعي'), style: const TextStyle(fontWeight: FontWeight.w900))),
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

  Widget _hero(HouseholdBudgetPlan plan) {
    final income = plan.input.monthlyIncome;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [scheme.primary, const Color(0xFF143D36)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('HOUSEHOLD ECONOMY', 'اقتصاد الأسرة'), style: const TextStyle(color: Color(0xFFE6C98B), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(_t('Your money needs a manager, not a ledger.', 'فلوس البيت محتاجة مدير اقتصادي، مش مجرد دفتر مصروفات.'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 18),
          Text(income > 0 ? _money(income) : _t('Real income required', 'لازم دخل حقيقي أولًا'), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_profileSaved ? _t('Household profile is saved to your account.', 'بيانات الأسرة محفوظة على حسابك.') : _t('No hidden sample income is used.', 'مفيش دخل افتراضي مستخبي جوه الخطة.'), style: TextStyle(color: Colors.white.withValues(alpha: .8), fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _profileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.family_restroom_rounded), const SizedBox(width: 8), Expanded(child: Text(_t('Household profile', 'ملف الأسرة'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), _pill(_profileSaved ? _t('SAVED', 'محفوظ') : _t('FIRST SETUP', 'إعداد أول مرة'))]),
          const SizedBox(height: 8),
          Text(_t('NUS uses these real details to plan for your household, location and currency.', 'NUS بيستخدم البيانات الحقيقية دي عشان يخطط لأسرتك ومكانك وعملتك، مش رقم افتراضي.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _textField(_countryController, _t('Country code', 'كود الدولة (مثال: EG)'), Icons.public_rounded, maxLength: 2)), const SizedBox(width: 10), Expanded(child: _textField(_currencyController, _t('Currency', 'العملة (مثال: EGP)'), Icons.payments_rounded, maxLength: 6))]),
          const SizedBox(height: 10),
          _textField(_regionController, _t('Region / city (optional)', 'المحافظة / المدينة (اختياري)'), Icons.location_on_outlined),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _numberStepper(_t('Adults', 'البالغين'), _adults, (v) => setState(() => _adults = v.clamp(1, 20)))), const SizedBox(width: 10), Expanded(child: _numberStepper(_t('Children', 'الأطفال'), _children, (v) => setState(() => _children = v.clamp(0, 20)))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(value: _housingType, decoration: InputDecoration(labelText: _t('Housing', 'نوع السكن'), filled: true, prefixIcon: const Icon(Icons.home_work_outlined)), items: [DropdownMenuItem(value: 'rent', child: Text(_t('Rent', 'إيجار'))), DropdownMenuItem(value: 'owned', child: Text(_t('Owned', 'تمليك'))), DropdownMenuItem(value: 'family', child: Text(_t('Family home', 'بيت العائلة'))), DropdownMenuItem(value: 'other', child: Text(_t('Other', 'أخرى')))], onChanged: (v) => setState(() => _housingType = v ?? 'rent'))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(value: _incomeFrequency, decoration: InputDecoration(labelText: _t('Income frequency', 'دورية الدخل'), filled: true, prefixIcon: const Icon(Icons.event_repeat_rounded)), items: [DropdownMenuItem(value: 'monthly', child: Text(_t('Monthly', 'شهري'))), DropdownMenuItem(value: 'weekly', child: Text(_t('Weekly', 'أسبوعي'))), DropdownMenuItem(value: 'biweekly', child: Text(_t('Biweekly', 'كل أسبوعين'))), DropdownMenuItem(value: 'irregular', child: Text(_t('Irregular', 'غير منتظم')))], onChanged: (v) => setState(() => _incomeFrequency = v ?? 'monthly'))),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _savingProfile ? null : () async { await _saveProfile(); if (mounted) setState(() => _plan = _buildPlan()); }, icon: _savingProfile ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_savingProfile ? _t('Saving…', 'جاري الحفظ…') : _t('Save household profile', 'احفظ بيانات الأسرة'))),
        ]),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label, IconData icon, {int? maxLength}) {
    return TextField(controller: controller, textCapitalization: TextCapitalization.characters, maxLength: maxLength, onChanged: (_) => setState(() { _aiRecommendation = null; _plan = _buildPlan(); }), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), filled: true, counterText: ''));
  }

  Widget _numberStepper(String title, int value, ValueChanged<int> onChanged) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(16)), child: Row(children: [Expanded(child: Text('$title\n$value', style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25))), IconButton(onPressed: value <= 0 ? null : () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline)), IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline))]));
  }

  Widget _actualCard(HouseholdBudgetActualComparison comparison) {
    final scheme = Theme.of(context).colorScheme;
    return Card(color: comparison.isOverPlan ? scheme.errorContainer : scheme.secondaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.fact_check_outlined), const SizedBox(width: 8), Text(_t('Reality check', 'مراجعة الواقع'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]), const SizedBox(height: 10), Row(children: [Expanded(child: _miniMetric(_t('Plan', 'الخطة'), _money(comparison.plannedAmount), Icons.flag_outlined)), const SizedBox(width: 10), Expanded(child: _miniMetric(_t('Actual', 'الفعلي'), _money(comparison.actualAmount), Icons.receipt_long_outlined))]), const SizedBox(height: 8), Text(comparison.managerMessage, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4))])));
  }

  Widget _inputSection({required String title, required String subtitle, required List<String> keys}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 5, height: 26, decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(8))), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)), const SizedBox(height: 12), ...keys.map((key) => _field(key))])));
  }

  Widget _field(String key) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: _controllers[key], keyboardType: const TextInputType.numberWithOptions(decimal: false), onChanged: (_) => setState(() { _aiRecommendation = null; _aiError = null; _plan = _buildPlan(); }), decoration: InputDecoration(labelText: _fields[key], suffixText: _currencyController.text.trim().isEmpty ? _t('currency', 'العملة') : _currencyController.text.trim().toUpperCase(), prefixIcon: Icon(_iconFor(key)), filled: true)));

  Widget _aiDecisionCard() {
    final recommendation = _aiRecommendation!;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.auto_awesome_rounded), const SizedBox(width: 8), Expanded(child: Text(_t('AI decision', 'قرار مدير البيت الذكي'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), _pill(_t('PROFILE-AWARE', 'مبني على الملف'))]), const SizedBox(height: 10), Text(recommendation.managerMessage, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)), const SizedBox(height: 10), Text(recommendation.recommendation, style: const TextStyle(height: 1.45))])));
  }

  Widget _managementCard(HouseholdBudgetManagement management) {
    final labels = <HouseholdBudgetPriority, String>{HouseholdBudgetPriority.essential: _t('Essential', 'أساسي'), HouseholdBudgetPriority.important: _t('Important', 'مهم'), HouseholdBudgetPriority.flexible: _t('Flexible', 'مرن'), HouseholdBudgetPriority.reserve: _t('Reserve', 'احتياطي')};
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_t('Manager instructions', 'تعليمات مدير البيت'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(management.managerMessage, style: const TextStyle(height: 1.45)), const Divider(height: 26), ...management.lines.map((line) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(_priorityIcon(line.priority)), title: Text(line.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${labels[line.priority]}${line.autoAllocated ? ' • ${_t('AI estimate', 'تقدير المدير')}' : ''}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(line.amount), style: const TextStyle(fontWeight: FontWeight.w900)), if (line.weeklyCap > 0) Text('${_money(line.weeklyCap)} / ${_t('week', 'أسبوع')}', style: const TextStyle(fontSize: 11))])))])));
  }

  Widget _statusCard(HouseholdBudgetPlan plan) {
    final title = switch (plan.status) {BudgetStatus.healthy => _t('Healthy plan', 'الخطة متوازنة'), BudgetStatus.tight => _t('Tight month', 'الشهر محتاج حذر'), BudgetStatus.overBudget => _t('Over budget', 'الخطة أعلى من الدخل'), BudgetStatus.incomplete => _t('Needs more information', 'الخطة محتاجة بيانات')};
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(plan.recommendation, style: const TextStyle(height: 1.45)), const Divider(height: 26), Row(children: [const Icon(Icons.savings_outlined), const SizedBox(width: 8), Expanded(child: Text(_t('Safety reserve', 'احتياطي الأمان'), style: const TextStyle(fontWeight: FontWeight.w800))), Text(_money(plan.reserve), style: const TextStyle(fontWeight: FontWeight.w900))])])));
  }

  Widget _errorCard(String message) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [const Icon(Icons.cloud_off_rounded), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)))])));

  Widget _miniMetric(String title, String value, IconData icon) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)), const SizedBox(height: 2), FittedBox(alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)))]))]));

  Widget _pill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(99)), child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .5)));

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
      case 'other': return Icons.more_horiz_rounded;
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