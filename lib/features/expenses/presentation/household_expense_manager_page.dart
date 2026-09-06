import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/expense_lifecycle_service.dart';
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
  static const _storageKey = 'nus.household_budget.v1';
  static const _fields = <String, String>{
    'income': 'الدخل الشهري',
    'rent': 'الإيجار / السكن',
    'utilities': 'المرافق والفواتير',
    'food': 'الأغذية والاحتياجات المنزلية',
    'transport': 'المواصلات / السيارة',
    'debt': 'الديون والأقساط',
    'health': 'الصحة والدواء',
    'clothing': 'الملابس',
    'maintenance': 'الصيانة والإصلاحات',
    'familyFun': 'الفسحة والعائلة',
    'other': 'مصروفات أخرى',
    'savingsTarget': 'هدف الادخار / الاحتياطي',
  };

  final Map<String, TextEditingController> _controllers = {};
  HouseholdBudgetPlan? _plan;
  int _actualThisMonth = 0;
  bool _loading = true;
  bool _saving = false;

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
      _controllers[key]!.text = prefs.getInt('$_storageKey.$key')?.toString() ?? '';
    }
    try {
      final expenses = await widget.service.list();
      final now = DateTime.now();
      _actualThisMonth = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
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

  HouseholdBudgetPlan _buildPlan() => buildHouseholdBudgetPlan(
        HouseholdBudgetInput(
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
        ),
      );

  Future<void> _saveAndPlan() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _plan = _buildPlan();
    });
    final prefs = await SharedPreferences.getInstance();
    for (final key in _fields.keys) {
      await prefs.setInt('$_storageKey.$key', _value(key));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t('Plan saved.', 'الخطة اتحفظت، ومدير المنزل جهّز لك التوزيع.'))),
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Household Expense Manager', 'مصروفات مدير المنزل')),
        actions: [
          IconButton(
            tooltip: _t('Expense ledger', 'سجل المصروفات'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExpensePage(service: widget.service, isArabic: widget.isArabic),
              ),
            ),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(plan),
          const SizedBox(height: 14),
          _summaryGrid(plan),
          const SizedBox(height: 18),
          _managementCard(plan.management),
          const SizedBox(height: 18),
          _sectionTitle('1', 'الدخل والالتزامات الأساسية', 'Income & essentials'),
          _field('income', Icons.payments_outlined, emphasized: true),
          _field('rent', Icons.home_outlined),
          _field('utilities', Icons.receipt_outlined),
          _field('food', Icons.shopping_basket_outlined),
          _field('transport', Icons.directions_car_outlined),
          _field('debt', Icons.account_balance_outlined),
          _field('health', Icons.health_and_safety_outlined),
          const SizedBox(height: 12),
          _sectionTitle('2', 'المصروفات المرنة وأسلوب الحياة', 'Flexible spending'),
          _field('clothing', Icons.checkroom_outlined),
          _field('maintenance', Icons.build_outlined),
          _field('familyFun', Icons.celebration_outlined),
          _field('other', Icons.more_horiz_rounded),
          _field('savingsTarget', Icons.savings_outlined),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _saveAndPlan,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_graph_rounded),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_saving ? _t('Saving…', 'بيجهّز الخطة…') : _t('Build my household plan', 'اعمل لي خطة تدبير البيت')),
            ),
          ),
          const SizedBox(height: 18),
          _statusCard(plan),
        ],
      ),
    );
  }

  Widget _heroCard(HouseholdBudgetPlan plan) => Card(
        elevation: 0,
        color: plan.status == BudgetStatus.overBudget
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(radius: 24, child: Icon(Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Your home has a financial manager now', 'بيتك بقى له مدير مالي جوّه البرنامج'),
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(
              _t(
                'Enter what you know. The manager fills missing planning envelopes, protects priorities, and leaves a buffer.',
                'إنت تدخل اللي تعرفه، ومدير المنزل يكمّل البنود الناقصة بتقدير مبدئي، ويحمي الأولويات، ويسيب لك هامش حركة.',
              ),
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 14),
            Text(
              plan.input.monthlyIncome > 0 ? _money(plan.input.monthlyIncome) : _t('Enter monthly income', 'لسه ما دخلتش الدخل الشهري'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            if (plan.input.monthlyIncome > 0)
              Text(_actualThisMonth > 0 ? '${_money(_actualThisMonth)} ${_t('recorded this month', 'مصروف مسجل هذا الشهر')}' : _t('No expenses recorded this month yet.', 'لسه مفيش مصروفات مسجلة الشهر ده.')),
          ]),
        ),
      );

  Widget _summaryGrid(HouseholdBudgetPlan plan) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.42,
        children: [
          _metricCard('الأساسيات', _money(plan.input.mandatoryTotal), Icons.lock_outline_rounded),
          _metricCard('هامش الحركة', _money(plan.remaining), Icons.account_balance_wallet_outlined),
          _metricCard('السقف الأسبوعي', _money(plan.weeklyAllowance), Icons.calendar_view_week_outlined),
          _metricCard('الاحتياطي', _money(plan.reserve), Icons.savings_outlined),
        ],
      );

  Widget _metricCard(String title, String value, IconData icon) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(alignment: AlignmentDirectional.centerStart, child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
          ]),
        ),
      );

  Widget _managementCard(HouseholdBudgetManagement management) {
    const labels = <HouseholdBudgetPriority, String>{
      HouseholdBudgetPriority.essential: 'أساسي',
      HouseholdBudgetPriority.important: 'مهم',
      HouseholdBudgetPriority.flexible: 'مرن',
      HouseholdBudgetPriority.reserve: 'احتياطي',
    };
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('خطة مدير المنزل', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(management.managerMessage, style: const TextStyle(height: 1.45)),
          const Divider(height: 28),
          ...management.lines.map(
            (line) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_priorityIcon(line.priority)),
              title: Text(line.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${labels[line.priority]}${line.autoAllocated ? ' • تقدير المدير' : ''}'),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_money(line.amount), style: const TextStyle(fontWeight: FontWeight.w900)),
                if (line.weeklyCap > 0) Text('${_money(line.weeklyCap)} / أسبوع', style: const TextStyle(fontSize: 11)),
              ]),
            ),
          ),
          const Divider(height: 24),
          Text('ترتيب التخفيض عند الضيق: ${management.cutOrder.join(' ← ')}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  IconData _priorityIcon(HouseholdBudgetPriority priority) {
    switch (priority) {
      case HouseholdBudgetPriority.essential:
        return Icons.shield_outlined;
      case HouseholdBudgetPriority.important:
        return Icons.warning_amber_rounded;
      case HouseholdBudgetPriority.flexible:
        return Icons.tune_rounded;
      case HouseholdBudgetPriority.reserve:
        return Icons.savings_outlined;
    }
  }

  Widget _sectionTitle(String number, String ar, String en) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(_t(en, ar), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        ]),
      );

  Widget _field(String key, IconData icon, {bool emphasized = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _controllers[key],
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _plan = _buildPlan()),
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            labelText: _fields[key],
            suffixText: _t('EGP', 'جنيه'),
            border: const OutlineInputBorder(),
            filled: emphasized,
          ),
        ),
      );

  Widget _statusCard(HouseholdBudgetPlan plan) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              plan.status == BudgetStatus.healthy
                  ? 'الخطة متوازنة'
                  : plan.status == BudgetStatus.tight
                      ? 'الخطة محتاجة حذر'
                      : 'الخطة أعلى من الدخل',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(plan.recommendation, style: const TextStyle(height: 1.45)),
            const Divider(height: 28),
            Row(children: [
              const Icon(Icons.date_range_outlined),
              const SizedBox(width: 10),
              const Expanded(child: Text('السقف الأسبوعي للمبلغ غير المخصص', style: TextStyle(fontWeight: FontWeight.w800))),
              Text(_money(plan.weeklyAllowance), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ]),
        ),
      );
}
