import 'package:flutter/material.dart';

import '../../expenses/application/expense_lifecycle_service.dart';
import '../../expenses/presentation/household_expense_manager_page.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../income/presentation/income_management_page.dart';
import '../../income/application/income_source_repository.dart';
import '../../income/domain/income_source.dart';
import '../domain/household_profile.dart';

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({
    super.key,
    required this.profile,
    this.incomeRepository,
    this.expenseService,
    this.onOpenGeneralHome,
    this.onSignOut,
  });

  final HouseholdProfile profile;
  final IncomeSourceRepository? incomeRepository;
  final ExpenseLifecycleService? expenseService;
  final void Function(BuildContext context)? onOpenGeneralHome;
  final VoidCallback? onSignOut;

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  late final IncomeSourceService _incomeService = IncomeSourceService(
    repository: widget.incomeRepository ?? const SupabaseIncomeSourceRepository(),
  );
  List<IncomeSource> _incomeSources = const <IncomeSource>[];
  bool _incomeLoading = true;
  String? _incomeError;

  @override
  void initState() {
    super.initState();
    _loadIncome();
  }

  Future<void> _loadIncome() async {
    setState(() {
      _incomeLoading = true;
      _incomeError = null;
    });
    try {
      final sources = await _incomeService.list(widget.profile.userId);
      if (!mounted) return;
      setState(() {
        _incomeSources = List<IncomeSource>.of(sources, growable: false);
        _incomeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _incomeSources = const <IncomeSource>[];
        _incomeLoading = false;
        _incomeError = 'مصادر الدخل التفصيلية غير متاحة الآن؛ بنحافظ على دخل إعداد البيت المحفوظ.';
      });
    }
  }

  int get _totalMonthlyIncome => _incomeSources.isEmpty
      ? widget.profile.monthlyIncome
      : _incomeService.totalMonthlyIncome(
          _incomeSources,
          currencyCode: widget.profile.currencyCode,
        );

  int get _remaining => _totalMonthlyIncome - widget.profile.recurringObligations;

  String _format(int value) {
    final text = value.abs().toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${parts.join(',')}';
  }

  String _money(int value) => '${_format(value)} ${widget.profile.currencyCode}';

  Future<void> _openIncomeManagement() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IncomeManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _incomeService,
        ),
      ),
    );
    if (changed == true && mounted) await _loadIncome();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remainingPositive = _remaining >= 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالتي المالية', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (widget.onSignOut != null)
            IconButton(tooltip: 'تسجيل الخروج', onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text('دي نقطة البداية الحقيقية لاقتصاد بيتك.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('${widget.profile.householdSize} أفراد · ${widget.profile.adults} بالغين · ${widget.profile.children} أطفال · ${widget.profile.currencyCode}'),
            const SizedBox(height: 18),
            Card(
              key: const ValueKey<String>('dashboard-income-card'),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('الدخل الشهري', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(_money(_totalMonthlyIncome), key: const ValueKey<String>('dashboard-total-monthly-income'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    if (_incomeLoading) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(key: ValueKey<String>('dashboard-income-loading')),
                    ],
                    if (_incomeError != null) ...[
                      const SizedBox(height: 8),
                      Text(_incomeError!, style: Theme.of(context).textTheme.bodySmall),
                      TextButton(onPressed: _loadIncome, child: const Text('إعادة تحميل مصادر الدخل')),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey<String>('dashboard-income-management'),
                      onPressed: _incomeLoading ? null : _openIncomeManagement,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('إدارة مصادر الدخل'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _metricCard(context, title: 'الالتزامات المتكررة الأولية', value: _money(widget.profile.recurringObligations), icon: Icons.receipt_long_rounded),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: remainingPositive ? scheme.primaryContainer : scheme.errorContainer,
                      foregroundColor: remainingPositive ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                      child: Icon(remainingPositive ? Icons.savings_outlined : Icons.warning_amber_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المتبقي بعد الالتزامات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_money(_remaining), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: remainingPositive ? scheme.primary : scheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('بيانات البداية', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text('الدولة: ${widget.profile.countryCode}'),
                    if (widget.profile.region != null && widget.profile.region!.isNotEmpty) Text('المنطقة: ${widget.profile.region}'),
                    Text('السكن: ${_housingLabel(widget.profile.housingType)}'),
                    Text('تكرار الدخل: ${_incomeFrequencyLabel(widget.profile.incomeFrequency)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (widget.expenseService != null)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HouseholdExpenseManagerPage(service: widget.expenseService!, isArabic: true))),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('إدارة مصروفات البيت'),
              ),
            if (widget.onOpenGeneralHome != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => widget.onOpenGeneralHome!(context),
                icon: const Icon(Icons.apps_rounded),
                label: const Text('فتح باقي أدوات NUS'),
              ),
            ],
            const SizedBox(height: 10),
            Text('الأرقام دي مبنية على بياناتك المحفوظة فقط. الدخل القديم يظل محفوظًا كمرجع متوافق مع إعداد البيت إلى أن تتوفر مصادر دخل تفصيلية.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: scheme.secondaryContainer, foregroundColor: scheme.onSecondaryContainer, child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _housingLabel(String value) => switch (value) {
        'rent' => 'إيجار',
        'owned' => 'تمليك',
        'family' => 'مع الأسرة',
        _ => 'أخرى',
      };

  String _incomeFrequencyLabel(String value) => switch (value) {
        'monthly' => 'شهري',
        'weekly' => 'أسبوعي',
        'biweekly' => 'كل أسبوعين',
        _ => 'غير منتظم',
      };
}
