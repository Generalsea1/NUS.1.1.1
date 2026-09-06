import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/expense_lifecycle_service.dart';
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
  static const _storageKey = 'nus.household_budget.v1';

  final Map<String, TextEditingController> _controllers = {};
  HouseholdBudgetPlan? _plan;
  int _actualThisMonth = 0;
  bool _loading = true;
  bool _saving = false;

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
          .where((expense) => expense.date.year == now.year && expense.date.month == now.month)
          .fold<int>(0, (sum, expense) => sum + expense.amount.minorUnits ~/ 100);
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

  HouseholdBudgetPlan _buildPlan() {
    return buildHouseholdBudgetPlan(
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
  }

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
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _heroCard(plan),
          const SizedBox(height: 14),
          _summaryGrid(plan),
          const SizedBox(height: 18),
          _sectionTitle('1', 'الدخل والالتزامات الأساسية', 'Income & essentials'),
          _field('income', icon: Icons.payments_outlined, emphasized: true),
          _field('rent', icon: Icons.home_outlined),
          _field('utilities', icon: Icons.receipt_outlined),
          _field('food', icon: Icons.shopping_basket_outlined),
          _field('transport', icon: Icons.directions_car_outlined),
          _field('debt', icon: Icons.account_balance_outlined),
          _field('health', icon: Icons.health_and_safety_outlined),
          const SizedBox(height: 12),
          _sectionTitle('2', 'المصروفات المرنة وأسلوب الحياة', 'Flexible spending'),
          _field('clothing', icon: Icons.checkroom_outlined),
          _field('maintenance', icon: Icons.build_outlined),
          _field('familyFun', icon: Icons.celebration_outlined),
          _field('other', icon: Icons.more_horiz_rounded),
          _field('savingsTarget', icon: Icons.savings_outlined),
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
          _weeklyCard(plan),
          const SizedBox(height: 14),
          _aiCard(),
        ],
      ),
    );
  }

  Widget _heroCard(HouseholdBudgetPlan plan) {
    final color = plan.status == BudgetStatus.overBudget
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer;
    return Card(
      elevation: 0,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.surface,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(
              _t('Your home has a financial manager now', 'بيتك بقى له مدير مالي جوّه البرنامج'),
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            )),
          ]),
          const SizedBox(height: 12),
          Text(
            _t(
              'Enter the income and commitments. The manager turns them into a practical monthly and weekly spending limit.',
              'إنت تدخل دخلك والتزاماتك، ومدير المنزل يحوّلهم لخطة عملية: إيه يتدفع الأول، وإيه يتحدد له سقف، وإزاي المبلغ يكفي الشهر.',
            ),
            style: const TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          Text(plan.input.monthlyIncome > 0 ? _money(plan.input.monthlyIncome) : _t('لم تدخل الدخل بعد', 'لم تدخل الدخل بعد'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          if (plan.input.monthlyIncome > 0)
            Text(
              _actualThisMonth > 0
                  ? _t('${_money(_actualThisMonth)} مصروف مسجل هذا الشهر', '${_money(_actualThisMonth)} مصروف مسجل هذا الشهر')
                  : _t('No expenses recorded this month yet.', 'لسه مفيش مصروفات مسجلة الشهر ده.'),
              style: const TextStyle(height: 1.5),
            ),
        ]),
      ),
    );
  }

  Widget _summaryGrid(HouseholdBudgetPlan plan) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.42,
      children: [
        _metricCard('الأساسيات', _money(plan.input.mandatoryTotal), Icons.lock_outline_rounded),
        _metricCard('المتاح بعد الخطة', _money(plan.remaining), Icons.account_balance_wallet_outlined),
        _metricCard('الحد الأسبوعي', _money(plan.weeklyAllowance), Icons.calendar_view_week_outlined),
        _metricCard('الاحتياطي', _money(plan.reserve), Icons.savings_outlined),
      ],
    );
  }

  Widget _metricCard(String title, String value, IconData icon) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20),
            const Spacer(),
            Text(title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FittedBox(
              alignment: AlignmentDirectional.centerStart,
              fit: BoxFit.scaleDown,
              child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );

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

  Widget _field(String key, {required IconData icon, bool emphasized = false}) {
    final label = _fields[key]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _controllers[key],
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() => _plan = _buildPlan()),
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: _t(label, label),
          suffixText: _t('EGP', 'جنيه'),
          border: const OutlineInputBorder(),
          filled: emphasized,
        ),
      ),
    );
  }

  Widget _weeklyCard(HouseholdBudgetPlan plan) {
    final statusText = switch (plan.status) {
      BudgetStatus.healthy => 'الخطة متوازنة',
      BudgetStatus.tight => 'الخطة محتاجة حذر',
      BudgetStatus.overBudget => 'الخطة أعلى من الدخل',
    };

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(statusText, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(plan.input.isOverBudget ? 'نوقف أي زيادة في المصروفات المرنة لحد ما الميزانية ترجع داخل الدخل.' : plan.recommendation,
              style: const TextStyle(height: 1.45)),
          const Divider(height: 28),
          Row(children: [
            const Icon(Icons.date_range_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text('السقف الأسبوعي المقترح للمبلغ غير المخصص', style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(_money(plan.weeklyAllowance), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
    );
  }

  Widget _aiCard() => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('Smart household advisor', 'مساعد مدير المنزل الذكي'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                _t(
                  'The same budget inputs are ready for the future AI layer: after account registration, the advisor can turn your history, priorities and family needs into adaptive weekly and monthly plans.',
                  'البنية دي معمولة مخصوص علشان الذكاء الاصطناعي يدخل عليها بعد تسجيل الحساب: ياخد دخلك، تاريخ مصروفاتك، أولوياتك واحتياجات أسرتك، ويطلع لك خطط أسبوعية وشهرية تتغير مع ظروفك بدل ما تكون مجرد أرقام ثابتة.',
                ),
                style: const TextStyle(height: 1.45),
              ),
            ])),
          ]),
        ),
      );
}
