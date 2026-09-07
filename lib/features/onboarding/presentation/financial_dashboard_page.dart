import 'package:flutter/material.dart';

import '../../expenses/application/expense_lifecycle_service.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../expenses/presentation/expense_management_page.dart';
import '../../expenses/presentation/household_expense_manager_page.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_engine.dart';
import '../../finance/presentation/financial_advisor_page.dart';
import '../../income/application/income_source_service.dart';
import '../../income/application/income_source_repository.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../income/domain/income_source.dart';
import '../../income/presentation/income_management_page.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../obligations/domain/obligation.dart';
import '../../obligations/presentation/obligation_management_page.dart';
import '../domain/household_profile.dart';

class FinancialDashboardPage extends StatefulWidget {
  const FinancialDashboardPage({
    super.key,
    required this.profile,
    this.incomeRepository,
    this.obligationService,
    this.expenseService,
    this.expenseManagementService,
    this.onOpenGeneralHome,
    this.onSignOut,
  });

  final HouseholdProfile profile;
  final IncomeSourceRepository? incomeRepository;
  final ObligationService? obligationService;
  final ExpenseLifecycleService? expenseService;
  final ExpenseManagementService? expenseManagementService;
  final void Function(BuildContext context)? onOpenGeneralHome;
  final VoidCallback? onSignOut;

  @override
  State<FinancialDashboardPage> createState() => _FinancialDashboardPageState();
}

class _FinancialDashboardPageState extends State<FinancialDashboardPage> {
  late final IncomeSourceService _incomeService =
      IncomeSourceService(repository: widget.incomeRepository ?? const SupabaseIncomeSourceRepository());
  late final ObligationService _obligationService =
      widget.obligationService ?? const ObligationService(repository: SupabaseObligationRepository());
  late final FinancialEngine? _financialEngine = widget.expenseManagementService == null
      ? null
      : FinancialEngine(
          incomeService: _incomeService,
          obligationService: _obligationService,
          expenseService: widget.expenseManagementService!,
        );

  List<IncomeSource> _incomeSources = const [];
  List<Obligation> _obligationItems = const [];
  FinancialSnapshot? _financialSnapshot;
  FinancialAdvisorSnapshot? _advisorSnapshot;
  late int _selectedYear = DateTime.now().year;
  late int _selectedMonth = DateTime.now().month;
  bool _incomeLoading = true;
  bool _obligationsLoading = true;
  bool _financialLoading = false;
  String? _incomeError;
  String? _obligationsError;
  String? _financialError;

  @override
  void initState() {
    super.initState();
    _loadIncome();
    _loadObligations();
    _loadFinancialSnapshot();
  }

  Future<void> _loadIncome() async {
    setState(() => _incomeLoading = true);
    try {
      final sources = await _incomeService.list(widget.profile.userId);
      if (!mounted) return;
      setState(() {
        _incomeSources = sources;
        _incomeLoading = false;
        _incomeError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _incomeSources = const [];
        _incomeLoading = false;
        _incomeError = 'مصادر الدخل التفصيلية غير متاحة الآن؛ بنحافظ على دخل إعداد البيت المحفوظ.';
      });
    }
  }

  Future<void> _loadObligations() async {
    setState(() => _obligationsLoading = true);
    try {
      final obligations = await _obligationService.list(widget.profile.userId);
      if (!mounted) return;
      setState(() {
        _obligationItems = obligations;
        _obligationsLoading = false;
        _obligationsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _obligationItems = const [];
        _obligationsLoading = false;
        _obligationsError = 'الالتزامات غير متاحة الآن. لن نعرض رقمًا قديمًا على أنه الإجمالي الحقيقي.';
      });
    }
  }

  Future<void> _loadFinancialSnapshot() async {
    final engine = _financialEngine;
    final expenseService = widget.expenseManagementService;
    if (engine == null || expenseService == null) return;
    setState(() {
      _financialLoading = true;
      _financialError = null;
      _advisorSnapshot = null;
    });
    try {
      final snapshot = await engine.calculate(
        userId: widget.profile.userId,
        year: _selectedYear,
        month: _selectedMonth,
        currencyCode: widget.profile.currencyCode,
      );
      if (!mounted) return;
      setState(() {
        _financialSnapshot = snapshot;
        _financialLoading = false;
      });
      try {
        final actualByCategory = await expenseService.monthlyActualByCategory(
          year: _selectedYear,
          month: _selectedMonth,
          currencyCode: widget.profile.currencyCode,
        );
        if (!mounted) return;
        setState(() {
          _advisorSnapshot = FinancialAdvisorSnapshot(
            financial: snapshot,
            actualByCategory: Map<String, int>.unmodifiable(actualByCategory),
          );
        });
      } catch (_) {
        // Advisor enrichment is optional; the authoritative financial snapshot stays intact.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _financialSnapshot = null;
        _advisorSnapshot = null;
        _financialLoading = false;
        _financialError = 'تعذر حساب الملخص المالي الآن.';
      });
    }
  }

  int get _income => _incomeSources.isEmpty
      ? widget.profile.monthlyIncome
      : _incomeService.totalMonthlyIncome(
          _incomeSources,
          currencyCode: widget.profile.currencyCode,
        );

  int get _totalMonthlyObligations =>
      _obligationsError == null
          ? _obligationService.totalMonthlyObligations(
              _obligationItems,
              currencyCode: widget.profile.currencyCode,
            )
          : 0;

  int get _remaining => _income - _totalMonthlyObligations;

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

  String _minorMoney(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.profile.currencyCode);
    final scale = metadata.scale;
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final absolute = minorUnits.abs();
    final whole = absolute ~/ scale;
    final fraction = (absolute % scale).toString().padLeft(metadata.exponent, '0');
    final sign = minorUnits < 0 ? '-' : '';
    return '$sign${_format(whole)}.$fraction ${metadata.code}';
  }

  String _monthLabel() => '${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختار الشهر المطلوب',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedYear = picked.year;
      _selectedMonth = picked.month;
    });
    await _loadFinancialSnapshot();
  }

  Future<void> _openIncomeManagement() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IncomeManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _incomeService,
        ),
      ),
    );
    if (!mounted) return;
    await _loadIncome();
    await _loadFinancialSnapshot();
  }

  Future<void> _openObligationManagement() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ObligationManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _obligationService,
        ),
      ),
    );
    if (!mounted) return;
    await _loadObligations();
    await _loadFinancialSnapshot();
  }

  void _openAdvisor() {
    final snapshot = _advisorSnapshot;
    if (snapshot == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FinancialAdvisorPage(snapshot: snapshot)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unavailable = _obligationsError != null;
    final positive = _remaining >= 0;
    final snapshot = _financialSnapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالتي المالية', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (widget.onSignOut != null)
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: widget.onSignOut,
              icon: const Icon(Icons.logout_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'دي نقطة البداية الحقيقية لاقتصاد بيتك.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text('${widget.profile.householdSize} أفراد · ${widget.profile.adults} بالغين · ${widget.profile.children} أطفال · ${widget.profile.currencyCode}'),
            const SizedBox(height: 18),
            _card(context, 'الدخل الشهري', _money(_income), Icons.account_balance_wallet_outlined, _incomeLoading, _incomeError, 'إدارة مصادر الدخل', _incomeLoading ? null : _openIncomeManagement),
            const SizedBox(height: 12),
            _card(context, 'الالتزامات الشهرية', unavailable ? 'غير متاح' : _money(_totalMonthlyObligations), Icons.receipt_long_rounded, _obligationsLoading, _obligationsError, 'إدارة الالتزامات', _obligationsLoading ? null : _openObligationManagement, _loadObligations),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: positive ? scheme.primaryContainer : scheme.errorContainer,
                      foregroundColor: positive ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                      child: Icon(positive ? Icons.savings_outlined : Icons.warning_amber_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المتبقي بعد الالتزامات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(unavailable ? 'غير متاح' : _money(_remaining), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: unavailable ? scheme.onSurface : (positive ? scheme.primary : scheme.error))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_financialEngine != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('ملخص الشهر', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
                          OutlinedButton.icon(key: const ValueKey<String>('financial-month-selector'), onPressed: _financialLoading ? null : _selectMonth, icon: const Icon(Icons.calendar_month_rounded), label: Text(_monthLabel())),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_financialLoading)
                        const LinearProgressIndicator()
                      else if (_financialError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_financialError!),
                            const SizedBox(height: 8),
                            TextButton.icon(onPressed: _loadFinancialSnapshot, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                          ],
                        )
                      else if (snapshot != null) ...[
                        _summaryMetric('الدخل الشهري', _money(snapshot.monthlyIncome), Icons.trending_up_rounded),
                        _summaryMetric('الالتزامات الشهرية', _money(snapshot.monthlyObligations), Icons.event_note_rounded),
                        _summaryMetric('المصروفات الفعلية', _minorMoney(snapshot.actualExpensesMinorUnits), Icons.payments_outlined),
                        _summaryMetric('المصروفات المتكررة المتوقعة', _minorMoney(snapshot.expectedRecurringExpensesMinorUnits), Icons.repeat_rounded),
                        const SizedBox(height: 6),
                        Container(
                          key: const ValueKey<String>('financial-position-card'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: scheme.secondaryContainer),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المركز المالي الآمن', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              Text('بعد المصروفات الفعلية: ${_minorMoney(snapshot.actualPositionMinorUnits)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('بعد الالتزامات: ${_money(snapshot.positionAfterObligations)}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text('الحسابان منفصلان عمدًا: لا يتم خصم الالتزام والمصروف المرتبط به مرتين.', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (_advisorSnapshot != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            key: const ValueKey<String>('financial-advisor-card'),
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text('المستشار المالي بالذكاء الاصطناعي', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text('يسأل ويشرح ويقترح فقط. كل رقم يقرأه يأتي من Financial Engine، ولا يستطيع تنفيذ أي إجراء مالي.'),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(key: const ValueKey<String>('open-financial-advisor'), onPressed: _openAdvisor, icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('اسأل المستشار')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (widget.expenseManagementService != null)
              FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseManagementPage(service: widget.expenseManagementService!))), icon: const Icon(Icons.receipt_long_rounded), label: const Text('مصروفات مدير المنزل')),
            if (widget.expenseService != null && widget.expenseManagementService == null)
              FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HouseholdExpenseManagerPage(service: widget.expenseService!, isArabic: true))), icon: const Icon(Icons.receipt_long_rounded), label: const Text('إدارة مصروفات البيت')),
            if (widget.onOpenGeneralHome != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: () => widget.onOpenGeneralHome!(context), icon: const Icon(Icons.apps_rounded), label: const Text('فتح باقي أدوات NUS')),
            ],
            const SizedBox(height: 10),
            Text('الأرقام الأساسية هنا تأتي من محركات الدخل والالتزامات، وبيانات المصروفات الفعلية والمتكررة لها مسار مستقل.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric(String title, String value, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
          child: Row(children: [Icon(icon, size: 22), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]),
        ),
      );

  Widget _card(BuildContext c, String title, String value, IconData icon, bool loading, String? error, String actionLabel, VoidCallback? onAction, [VoidCallback? retry]) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 12), Expanded(child: Text(title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)))]),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              if (loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error, style: Theme.of(c).textTheme.bodySmall),
                if (retry != null) TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.open_in_new_rounded), label: Text(actionLabel)),
            ],
          ),
        ),
      );
}
