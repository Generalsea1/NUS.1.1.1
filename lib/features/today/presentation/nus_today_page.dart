import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';
import '../../finance/application/household_intelligence_service.dart';
import '../../finance/presentation/ask_nus_page.dart';
import '../../finance/presentation/household_intelligence_page.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../income/domain/income_source.dart';
import '../../income/presentation/income_management_page.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../obligations/domain/obligation.dart';
import '../../obligations/presentation/obligation_management_page.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../shopping/application/shopping_lifecycle_service.dart';
import '../../finance/presentation/household_intelligence_page.dart';
import '../../../legacy_main.dart' as legacy;

class NusTodayPage extends StatefulWidget {
  const NusTodayPage({
    super.key,
    required this.profile,
    this.scheduleStore,
    this.expenseManagementService,
    this.shoppingService,
    this.onOpenAppointments,
    this.onOpenFinance,
    this.onCreateReminder,
  });

  final HouseholdProfile profile;
  final legacy.ScheduleStore? scheduleStore;
  final ExpenseManagementService? expenseManagementService;
  final ShoppingLifecycleService? shoppingService;
  final VoidCallback? onOpenAppointments;
  final VoidCallback? onOpenFinance;
  final Future<void> Function(String title, DateTime dateTime)? onCreateReminder;

  @override
  State<NusTodayPage> createState() => _NusTodayPageState();
}

class _NusTodayPageState extends State<NusTodayPage> {
  late final IncomeSourceService _incomeService =
      const IncomeSourceService(repository: SupabaseIncomeSourceRepository());
  late final ObligationService _obligationService =
      const ObligationService(repository: SupabaseObligationRepository());
  late final FinancialEngine? _engine = widget.expenseManagementService == null
      ? null
      : FinancialEngine(
          incomeService: _incomeService,
          obligationService: _obligationService,
          expenseService: widget.expenseManagementService!,
        );
  late final HouseholdIntelligenceService? _intelligence =
      _engine == null || widget.expenseManagementService == null
          ? null
          : HouseholdIntelligenceService(
              financialEngine: _engine!,
              expenseService: widget.expenseManagementService!,
              incomeService: _incomeService,
            );

  List<IncomeSource> _incomeSources = const <IncomeSource>[];
  List<Obligation> _obligationItems = const <Obligation>[];
  FinancialSnapshot? _snapshot;
  FinancialAdvisorSnapshot? _advisorSnapshot;
  AiInsight? _dailyTip;
  bool _loading = true;
  bool _tipLoading = false;
  String? _error;
  bool _showAllCategories = false;
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>([
        _incomeService.list(widget.profile.userId),
        _obligationService.list(widget.profile.userId),
        if (_engine != null)
          _engine!.calculate(
            userId: widget.profile.userId,
            year: _year,
            month: _month,
            currencyCode: widget.profile.currencyCode,
          ),
      ]);
      final incomes = results[0] as List<IncomeSource>;
      final obligationItems = results[1] as List<Obligation>;
      final snapshot = _engine == null ? null : results[2] as FinancialSnapshot;
      Map<String, int> categories = const <String, int>{};
      if (widget.expenseManagementService != null) {
        try {
          categories = await widget.expenseManagementService!.monthlyActualByCategory(
            year: _year,
            month: _month,
            currencyCode: widget.profile.currencyCode,
          );
        } catch (_) {
          categories = const <String, int>{};
        }
      }
      if (!mounted) return;
      setState(() {
        _incomeSources = incomes;
        _obligationItems = obligationItems;
        _snapshot = snapshot;
        _advisorSnapshot = snapshot == null
            ? null
            : FinancialAdvisorSnapshot(
                financial: snapshot,
                actualByCategory: Map<String, int>.unmodifiable(categories),
              );
        _loading = false;
      });
      unawaited(_loadDailyTip());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تجهيز الملخص المالي الآن. بياناتك المحفوظة لم يتم تعديلها.';
      });
    }
  }

  Future<void> _loadDailyTip({bool force = false}) async {
    final snapshot = _advisorSnapshot;
    if (snapshot == null || _tipLoading) return;
    final key = 'nus.ai.daily_tip.${snapshot.financial.year}-${snapshot.financial.month}.${widget.profile.currencyCode}';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (!force && cached != null && cached.trim().isNotEmpty) {
      if (mounted) setState(() => _dailyTip = AiInsight(id: 'cached', summary: cached, generatedAt: DateTime.now(), sourceDomain: 'daily_tip'));
      return;
    }
    if (!mounted) return;
    setState(() => _tipLoading = true);
    try {
      final request = snapshot.toAiRequest();
      final insight = await const FinancialAdvisorProvider().generateInsight(
        AiInsightRequest(
          objective: 'Give one short practical financial tip for today based only on the supplied household facts. Do not invent any number. Do not mention the AI provider. Maximum 2 sentences.',
          context: request.context,
        ),
      );
      await prefs.setString(key, insight.summary);
      if (!mounted) return;
      setState(() => _dailyTip = insight);
    } catch (_) {
      // AI tip is optional and must never block the financial dashboard.
    } finally {
      if (mounted) setState(() => _tipLoading = false);
    }
  }

  int get _income => _incomeSources.isEmpty
      ? widget.profile.monthlyIncome
      : _incomeService.totalMonthlyIncome(_incomeSources, currencyCode: widget.profile.currencyCode);

  int get _obligations => _obligationService.totalMonthlyObligations(
        _obligationItems,
        currencyCode: widget.profile.currencyCode,
      );

  int get _actual => _snapshot?.actualExpensesMinorUnits ?? 0;
  int get _position => _snapshot?.actualPositionMinorUnits ?? (_income - _obligations);

  List<MapEntry<String, int>> get _categories {
    final map = _advisorSnapshot?.actualByCategory ?? const <String, int>{};
    final items = map.entries.where((entry) => entry.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _showAllCategories ? items : items.take(5).toList();
  }

  String _money(int value) => '${_format(value)} ${widget.profile.currencyCode}';

  String _format(int value) {
    final raw = value.abs().toString();
    final chunks = <String>[];
    for (var i = raw.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      chunks.insert(0, raw.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  Future<void> _openAskNus() async {
    final snapshot = _advisorSnapshot;
    if (snapshot == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AskNusPage(snapshot: snapshot)));
  }

  Future<void> _openIncome() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => IncomeManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _incomeService,
        )));
    await _refresh();
  }

  Future<void> _openObligations() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ObligationManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _obligationService,
        )));
    await _refresh();
  }

  Future<void> _openIntelligence() async {
    final intelligence = _intelligence;
    if (intelligence == null) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HouseholdIntelligencePage(
          service: intelligence,
          userId: widget.profile.userId,
          year: _year,
          month: _month,
          currencyCode: widget.profile.currencyCode,
        )));
  }

  Future<void> _chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_year, _month, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'اختار الشهر',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _year = picked.year;
      _month = picked.month;
      _dailyTip = null;
    });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _snapshot;
    final positive = _position >= 0;
    return Scaffold(
      backgroundColor: Color.alphaBlend(scheme.primaryContainer.withOpacity(.16), scheme.surface),
      appBar: AppBar(
        title: const Text('NUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _openAskNus, tooltip: 'اسأل NUS', icon: const Icon(Icons.auto_awesome_rounded)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _welcomeHeader(context),
              const SizedBox(height: 12),
              _monthPill(context),
              const SizedBox(height: 12),
              if (_dailyTip != null || _tipLoading) _tipCard(context),
              const SizedBox(height: 12),
              _positionHero(context, positive),
              const SizedBox(height: 12),
              _metricsGrid(context, snapshot),
              const SizedBox(height: 14),
              _priorityActions(context),
              const SizedBox(height: 14),
              if (_loading)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
              else if (_error != null)
                _errorCard(context)
              else ...[
                _spendingChart(context),
                const SizedBox(height: 14),
                _moneyFlowCard(context, snapshot),
                const SizedBox(height: 14),
                if (_intelligence != null) _insightCard(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _welcomeHeader(BuildContext context) => Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary]),
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x33000000))],
            ),
            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مساحة التحكم المالي لبيتك', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('${widget.profile.householdSize} أفراد · ${widget.profile.currencyCode}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ])),
        ],
      );

  Widget _monthPill(BuildContext context) => Row(children: [
        Expanded(child: Text('الأرقام الحقيقية أولًا؛ ثم القرار.', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))),
        OutlinedButton.icon(onPressed: _loading ? null : _chooseMonth, icon: const Icon(Icons.calendar_month_rounded, size: 18), label: Text('${_month.toString().padLeft(2, '0')}/$_year')),
      ]);

  Widget _tipCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(color: scheme.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.lightbulb_rounded, color: scheme.onTertiaryContainer),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نصيحة NUS', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onTertiaryContainer)),
        const SizedBox(height: 4),
        _tipLoading ? const LinearProgressIndicator() : Text(_dailyTip?.summary ?? '', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer)),
      ])),
    ])));
  }

  Widget _positionHero(BuildContext context, bool positive) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _snapshot;
    final actual = snapshot?.actualPositionMinorUnits ?? _position;
    final obligated = snapshot?.positionAfterObligations ?? (_income - _obligations);
    return Card(clipBehavior: Clip.antiAlias, child: Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: positive ? [scheme.primaryContainer, scheme.surface] : [scheme.errorContainer, scheme.surface], begin: Alignment.topRight, end: Alignment.bottomLeft)),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.speed_rounded), const SizedBox(width: 7), const Text('المركز المالي الآن', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Icon(positive ? Icons.check_circle_rounded : Icons.warning_rounded)]),
        const SizedBox(height: 7),
        Text(_money(actual), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 3),
        Text('المتبقي بعد المصروفات الفعلية', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: _microMetric('بعد الالتزامات', _money(obligated))), Expanded(child: _microMetric('دخل الشهر', _money(_income)))]),
      ]),
    ));
  }

  Widget _microMetric(String title, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]);

  Widget _metricsGrid(BuildContext context, FinancialSnapshot? snapshot) => GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.62,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _metricCard(context, 'الدخل', _money(_income), Icons.south_west_rounded),
          _metricCard(context, 'الالتزامات', _money(_obligations), Icons.lock_outline_rounded),
          _metricCard(context, 'المصروف الفعلي', _money(snapshot?.actualExpensesMinorUnits ?? 0), Icons.payments_outlined),
          _metricCard(context, 'المتكرر المتوقع', snapshot == null ? '—' : _money(snapshot.expectedRecurringExpensesMinorUnits), Icons.repeat_rounded),
        ],
      );

  Widget _metricCard(BuildContext context, String title, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x12000000))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 21),
        const Spacer(),
        Text(title, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _priorityActions(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
    Expanded(child: _actionButton('اسأل NUS', Icons.auto_awesome_rounded, _openAskNus)),
    Expanded(child: _actionButton('الدخل', Icons.account_balance_wallet_outlined, _openIncome)),
    Expanded(child: _actionButton('الالتزامات', Icons.receipt_long_rounded, _openObligations)),
  ])));

  Widget _actionButton(String title, IconData icon, VoidCallback onPressed) => InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4), child: Column(children: [Icon(icon, size: 25), const SizedBox(height: 5), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))])));

  Widget _spendingChart(BuildContext context) {
    final entries = _categories;
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.value);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text('كيف توزّع إنفاقك؟', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), if (_categories.length >= 5) TextButton(onPressed: () => setState(() => _showAllCategories = !_showAllCategories), child: Text(_showAllCategories ? 'أقل' : 'كل الفئات'))]),
      const SizedBox(height: 12),
      if (total <= 0)
        const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('لم نسجل مصروفات فعلية كافية لنعرض توزيعًا حقيقيًا.')))
      else
        SizedBox(height: 230, child: Row(children: [
          SizedBox(width: 142, child: CustomPaint(painter: _DonutPainter(entries: entries, total: total), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('الفعلية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), Text(_money(total), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))])))),
          const SizedBox(width: 14),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [for (final entry in entries) Padding(padding: const EdgeInsets.only(bottom: 9), child: _categoryBar(context, entry, total))])),
        ])),
    ])));
  }

  Widget _categoryBar(BuildContext context, MapEntry<String, int> entry, int total) {
    final ratio = entry.value / total;
    return Row(children: [
      Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
      SizedBox(width: 84, child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 8))),
      const SizedBox(width: 8),
      SizedBox(width: 38, child: Text('${(ratio * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
    ]);
  }

  Widget _moneyFlowCard(BuildContext context, FinancialSnapshot? snapshot) {
    if (snapshot == null) return const SizedBox.shrink();
    final committed = _obligations + snapshot.expectedRecurringExpensesMinorUnits;
    final available = _income - committed;
    final ratio = _income <= 0 ? 0.0 : (committed / _income).clamp(0.0, 1.0);
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ضغط الميزانية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('كم من الدخل أصبح ملتزمًا قبل المصروفات الجديدة؟'),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 12)),
      const SizedBox(height: 9),
      Row(children: [Expanded(child: Text('${(ratio * 100).round()}% التزام متوقع', style: const TextStyle(fontWeight: FontWeight.w900))), Text(_money(available), style: const TextStyle(fontWeight: FontWeight.w900))]),
      const SizedBox(height: 4),
      Text('متاح نظريًا بعد الالتزامات والمتكرر المتوقع — لا نعتبره نقدًا فعليًا في اليد.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ])));
  }

  Widget _insightCard(BuildContext context) => Card(color: Theme.of(context).colorScheme.secondaryContainer, child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        leading: const Icon(Icons.insights_rounded),
        title: const Text('تحليل البيت', style: TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('عرض أعمق للمخاطر والقدرة المالية باستخدام نفس الأرقام الفعلية.'),
        trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onTap: _openIntelligence,
      ));

  Widget _errorCard(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.error_outline_rounded), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('الملخص المالي غير مكتمل', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('$_error'), const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
    ])),
  ])));
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.entries, required this.total});
  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 12;
    final stroke = radius * .30;
    var start = -3.141592653589793 / 2;
    const palette = <Color>[
      Color(0xFF4F46E5), Color(0xFF0891B2), Color(0xFF16A34A), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF0F766E), Color(0xFF64748B),
    ];
    for (var index = 0; index < entries.length; index++) {
      final sweep = (entries[index].value / total) * 2 * 3.141592653589793;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = palette[index % palette.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.total != total || oldDelegate.entries != entries;
}
