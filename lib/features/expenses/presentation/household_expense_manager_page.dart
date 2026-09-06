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
  const HouseholdExpenseManagerPage({super.key, required this.service, this.isArabic = true});

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
    for (final controller in _controllers.values) controller.dispose();
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
        // Local values remain available when cloud profile retrieval is unavailable.
      }
    }

    try {
      final expenses = await widget.service.list();
      final now = DateTime.now();
      final currency = _currencyController.text.trim().toUpperCase();
      _actualThisMonth = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month &&
              (currency.isEmpty || e.amount.currencyCode == currency))
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
      _showMessage(_t('Sign in first to save your household data.', 'سجّل الدخول الأول علشان نحفظ بيانات البيت على حسابك.'));
      return false;
    }
    if (country.length != 2 || currency.length < 3 || income <= 0) {
      _showMessage(_t('Enter country, currency and your real monthly income.', 'اكتب الدولة والعملة والدخل الشهري الحقيقي الأول.'));
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
        'budget_snapshot': {for (final key in _fields.keys) key: _value(key), 'providedFields': _input().providedFields.toList(growable: false)},
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final prefs = await SharedPreferences.getInstance();
      for (final key in _fields.keys) await prefs.setInt('$_storageKey.$key', _value(key));
      if (!mounted) return true;
      setState(() => _profileSaved = true);
      return true;
    } on PostgrestException catch (error) {
      _showMessage(error.message);
      return false;
    } catch (_) {
      _showMessage(_t('Could not save the household profile right now.', 'ماقدرتش أحفظ بيانات البيت دلوقتي.'));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)));
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
    final dark = base.brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0B776B), brightness: base.brightness);
    final theme = base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? const Color(0xFF081310) : const Color(0xFFF5F2EA),
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: dark ? const Color(0xFF081310) : const Color(0xFFF5F2EA), surfaceTintColor: Colors.transparent, elevation: 0),
      cardTheme: CardThemeData(margin: EdgeInsets.zero, elevation: 0, color: dark ? const Color(0xFF12201C) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: dark ? const Color(0xFF172722) : const Color(0xFFF0F3F0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.3)),
      ),
    );

    return Theme(
      data: theme,
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_t('Household Expenses', 'مصروفات مدير المنزل'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
            actions: [
              IconButton(tooltip: _t('AI connection', 'اتصال الذكاء الاصطناعي'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AiSettingsPage(isArabic: widget.isArabic))), icon: const Icon(Icons.auto_awesome_rounded)),
              IconButton(tooltip: _t('Expense ledger', 'سجل المصروفات'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpensePage(service: widget.service, isArabic: widget.isArabic))), icon: const Icon(Icons.receipt_long_rounded)),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
              children: [
                _hero(plan),
                const SizedBox(height: 12),
                _profileCard(),
                const SizedBox(height: 12),
                _actualCard(comparison),
                const SizedBox(height: 12),
                _quickSummary(plan),
                if (_aiError != null) ...[const SizedBox(height: 12), _errorCard(_aiError!)],
                if (plan.isAiPowered) ...[const SizedBox(height: 12), _aiDecisionCard()],
                const SizedBox(height: 12),
                _sectionCard(title: _t('1. Essential home costs', '١. الأساسيات التي لا تتأجل'), subtitle: _t('Protect these first. The manager works around them.', 'دي أول بنود الحماية. مدير البيت بيوزّع الباقي حواليها.'), keys: _essentialKeys, icon: Icons.shield_outlined),
                const SizedBox(height: 12),
                _sectionCard(title: _t('2. Flexible spending', '٢. المصروفات المرنة'), subtitle: _t('These are the first categories to trim when money is tight.', 'دي أول بنود نقدر نقللها وقت الضغط.'), keys: _flexibleKeys, icon: Icons.tune_rounded),
                const SizedBox(height: 12),
                _sectionCard(title: _t('3. Financial safety', '٣. الأمان المالي'), subtitle: _t('Set a target for the household reserve.', 'حدد هدف احتياطي الأمان للأسرة.'), keys: const ['savingsTarget'], icon: Icons.savings_outlined),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _aiLoading || _savingProfile ? null : _buildWithAi,
                  icon: _aiLoading || _savingProfile ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded),
                  label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(_aiLoading ? _t('Building your household plan…', 'مدير البيت الذكي بيبني الخطة…') : _t('Manage my month with AI', 'دبّر لي الشهر بالذكاء الاصطناعي'), style: const TextStyle(fontWeight: FontWeight.w900))),
                ),
                const SizedBox(height: 12),
                _managementCard(plan.management),
                const SizedBox(height: 12),
                _statusCard(plan),
              ],
            ),
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
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [scheme.primary, const Color(0xFF084B44)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .13), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.home_work_rounded, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text(_t('HOUSEHOLD BUDGET MANAGER', 'مصروفات مدير المنزل'), style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: .7))),
            if (_profileSaved) _heroBadge(_t('Saved', 'محفوظ')),
          ]),
          const SizedBox(height: 16),
          Text(_t('Make the salary last to the end of the month.', 'خلّي مرتبك يكفي البيت لآخر الشهر.'), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 7),
          Text(_t('The manager sets priorities, protects essentials and cuts flexible spending before the month gets away from you.', 'البرنامج بيرتب الأولويات، ويحمي الأساسيات، ويقلل البنود المرنة قبل ما الشهر يفلت منك.'), style: TextStyle(color: Colors.white.withValues(alpha: .82), height: 1.4)),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.payments_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_t('Real monthly income', 'الدخل الشهري الحقيقي'), style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(income > 0 ? _money(income) : _t('Enter your income below', 'اكتب دخلك الحقيقي تحت'), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
              ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _heroBadge(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)));

  Widget _profileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [_sectionIcon(Icons.family_restroom_rounded), const SizedBox(width: 10), Expanded(child: Text(_t('بيانات البيت', 'بيانات البيت'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), _pill(_profileSaved ? _t('READY', 'جاهز') : _t('SETUP', 'إعداد'))]),
          const SizedBox(height: 6),
          Text(_t('Tell the manager about your real household before asking it to plan.', 'قول لمدير البيت بياناتك الحقيقية الأول قبل ما تطلب منه يدبّر الشهر.'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _compactTextField(_countryController, _t('Country', 'الدولة'), 'EG', Icons.public_rounded, maxLength: 2)), const SizedBox(width: 10), Expanded(child: _compactTextField(_currencyController, _t('Currency', 'العملة'), 'EGP', Icons.payments_rounded, maxLength: 6))]),
          const SizedBox(height: 10),
          _compactTextField(_regionController, _t('City / governorate (optional)', 'المدينة / المحافظة (اختياري)'), _t('Cairo', 'القاهرة'), Icons.location_on_outlined),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _compactStepper(_t('Adults', 'بالغين'), _adults, (value) => setState(() => _adults = value.clamp(1, 20).toInt())),
            _compactStepper(_t('Children', 'أطفال'), _children, (value) => setState(() => _children = value.clamp(0, 20).toInt())),
          ]),
          const SizedBox(height: 10),
          _dropdownField(label: _t('Housing type', 'نوع السكن'), value: _housingType, icon: Icons.home_work_outlined, items: {'rent': _t('Rent', 'إيجار'), 'owned': _t('Owned', 'تمليك'), 'family': _t('Family home', 'بيت العائلة'), 'other': _t('Other', 'أخرى')}, onChanged: (value) => setState(() => _housingType = value)),
          const SizedBox(height: 10),
          _dropdownField(label: _t('Income frequency', 'دورية الدخل'), value: _incomeFrequency, icon: Icons.event_repeat_rounded, items: {'monthly': _t('Monthly', 'شهري'), 'weekly': _t('Weekly', 'أسبوعي'), 'biweekly': _t('Every two weeks', 'كل أسبوعين'), 'irregular': _t('Irregular', 'غير منتظم')}, onChanged: (value) => setState(() => _incomeFrequency = value)),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _savingProfile ? null : () async { await _saveProfile(); if (mounted) setState(() => _plan = _buildPlan()); }, icon: _savingProfile ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cloud_done_outlined), label: Text(_savingProfile ? _t('Saving…', 'جاري الحفظ…') : _t('Save household data', 'احفظ بيانات البيت'))),
        ]),
      ),
    );
  }

  Widget _compactTextField(TextEditingController controller, String label, String hint, IconData icon, {int? maxLength}) {
    return TextField(controller: controller, maxLength: maxLength, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, size: 20), counterText: ''), onChanged: (_) => setState(() { _aiRecommendation = null; _aiError = null; _plan = _buildPlan(); }));
  }

  Widget _compactStepper(String title, int value, ValueChanged<int> onChanged) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))]),
        const SizedBox(width: 6),
        IconButton(visualDensity: VisualDensity.compact, onPressed: value <= 0 ? null : () => onChanged(value - 1), icon: const Icon(Icons.remove_circle_outline, size: 22)),
        IconButton(visualDensity: VisualDensity.compact, onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_circle_outline, size: 22)),
      ]),
    );
  }

  Widget _dropdownField({required String label, required String value, required IconData icon, required Map<String, String> items, required ValueChanged<String> onChanged}) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      items: [for (final entry in items.entries) DropdownMenuItem<String>(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))],
      onChanged: (next) { if (next != null) onChanged(next); },
    );
  }

  Widget _actualCard(HouseholdBudgetActualComparison comparison) {
    final scheme = Theme.of(context).colorScheme;
    final tone = comparison.isOverPlan ? scheme.errorContainer : scheme.secondaryContainer;
    return Card(color: tone, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(comparison.isOverPlan ? Icons.warning_amber_rounded : Icons.fact_check_outlined), const SizedBox(width: 8), Text(_t('Reality check', 'مراجعة الواقع'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _metric(_t('Plan', 'الخطة'), _money(comparison.plannedAmount), Icons.flag_outlined)), const SizedBox(width: 10), Expanded(child: _metric(_t('Actual', 'الفعلي'), _money(comparison.actualAmount), Icons.receipt_long_outlined))]),
      const SizedBox(height: 10),
      Text(comparison.managerMessage, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
    ])));
  }

  Widget _quickSummary(HouseholdBudgetPlan plan) {
    final plannedSpend = (plan.plannedTotal - plan.reserve).clamp(0, 0x7fffffffffffffff);
    final remaining = (plan.input.monthlyIncome - _actualThisMonth).clamp(0, 0x7fffffffffffffff);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Wrap(spacing: 10, runSpacing: 10, children: [
      _summaryTile(Icons.account_balance_wallet_outlined, _t('Monthly income', 'الدخل'), _money(plan.input.monthlyIncome)),
      _summaryTile(Icons.donut_small_outlined, _t('Planned spend', 'المخطط'), _money(plannedSpend)),
      _summaryTile(Icons.savings_outlined, _t('Safety reserve', 'الاحتياطي'), _money(plan.reserve)),
      _summaryTile(Icons.trending_down_rounded, _t('Still available', 'المتاح الآن'), _money(remaining)),
    ])));
  }

  Widget _summaryTile(IconData icon, String label, String value) => SizedBox(width: 148, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .48), borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, size: 19), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))) ]))])));

  Widget _sectionCard({required String title, required String subtitle, required List<String> keys, required IconData icon}) => Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [_sectionIcon(icon), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]), const SizedBox(height: 5), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)), const SizedBox(height: 10), ...keys.map(_field)]));

  Widget _field(String key) {
    final currency = _currencyController.text.trim().toUpperCase();
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(
      controller: _controllers[key],
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: _fields[key], hintText: _t('Enter amount', 'اكتب المبلغ'), suffixText: currency.isEmpty ? null : currency, prefixIcon: Icon(_iconFor(key), size: 20)),
      onChanged: (_) => setState(() { _aiRecommendation = null; _aiError = null; _plan = _buildPlan(); }),
    ));
  }

  Widget _aiDecisionCard() {
    final recommendation = _aiRecommendation!;
    final onPrimary = Theme.of(context).colorScheme.onPrimaryContainer;
    return Card(color: Theme.of(context).colorScheme.primaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Icon(Icons.auto_awesome_rounded, color: onPrimary), const SizedBox(width: 8), Expanded(child: Text(_t('AI household decision', 'قرار مدير البيت الذكي'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: onPrimary))), _pill(_t('AI', 'AI'))]),
      const SizedBox(height: 10), Text(recommendation.managerMessage, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.45)), const SizedBox(height: 8), Text(recommendation.recommendation, style: const TextStyle(height: 1.45)),
    ])));
  }

  Widget _managementCard(HouseholdBudgetManagement management) {
    final labels = <HouseholdBudgetPriority, String>{HouseholdBudgetPriority.essential: _t('Essential', 'أساسي'), HouseholdBudgetPriority.important: _t('Important', 'مهم'), HouseholdBudgetPriority.flexible: _t('Flexible', 'مرن'), HouseholdBudgetPriority.reserve: _t('Reserve', 'احتياطي')};
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(_t('How the manager allocates the month', 'إزاي مدير البيت بيدبّر الشهر'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(management.managerMessage, style: const TextStyle(height: 1.45)), const Divider(height: 24), ...management.lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(_priorityIcon(line.priority), size: 21), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${labels[line.priority]}${line.autoAllocated ? ' • ${_t('AI estimate', 'تقدير المدير')}' : ''}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant))])), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(_money(line.amount), style: const TextStyle(fontWeight: FontWeight.w900))), if (line.weeklyCap > 0) Text('${_money(line.weeklyCap)} / ${_t('week', 'أسبوع')}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant))])]))]));
  }

  Widget _statusCard(HouseholdBudgetPlan plan) {
    final title = switch (plan.status) {
      BudgetStatus.healthy => _t('The month is manageable', 'الشهر قابل للإدارة'),
      BudgetStatus.tight => _t('The month is tight', 'الشهر محتاج حذر'),
      BudgetStatus.overBudget => _t('The plan is above income', 'الخطة أعلى من الدخل'),
      BudgetStatus.incomplete => _t('More information is needed', 'الخطة محتاجة بيانات أكثر'),
    };
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [const Icon(Icons.insights_rounded), const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))]), const SizedBox(height: 8), Text(plan.recommendation, style: const TextStyle(height: 1.45)), const Divider(height: 24), Row(children: [const Icon(Icons.savings_outlined), const SizedBox(width: 8), Expanded(child: Text(_t('Safety reserve', 'احتياطي الأمان'), style: const TextStyle(fontWeight: FontWeight.w800))), FittedBox(fit: BoxFit.scaleDown, child: Text(_money(plan.reserve), style: const TextStyle(fontWeight: FontWeight.w900)))])]));
  }

  Widget _errorCard(String message) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.cloud_off_rounded), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)))])));

  Widget _metric(String title, String value, IconData icon) => Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(15)), child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 2), FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)))])]));

  Widget _sectionIcon(IconData icon) => Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 21));

  Widget _pill(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(99)), child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)));

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
