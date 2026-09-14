import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';
import '../../finance/application/household_intelligence_service.dart';
import '../../finance/presentation/ask_nus_page.dart';
import '../../finance/presentation/household_intelligence_page.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../income/presentation/income_management_page.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../../obligations/presentation/obligation_management_page.dart';
import '../../onboarding/domain/household_profile.dart';

class NusFinancialHomePage extends StatefulWidget {
  const NusFinancialHomePage({
    super.key,
    required this.profile,
    required this.expenseManagementService,
    this.onSignOut,
  });

  final HouseholdProfile profile;
  final ExpenseManagementService expenseManagementService;
  final VoidCallback? onSignOut;

  @override
  State<NusFinancialHomePage> createState() => _NusFinancialHomePageState();
}

class _NusFinancialHomePageState extends State<NusFinancialHomePage> {
  late final IncomeSourceService _incomeService = const IncomeSourceService(repository: SupabaseIncomeSourceRepository());
  late final ObligationService _obligationService = const ObligationService(repository: SupabaseObligationRepository());
  late final FinancialEngine _engine = FinancialEngine(
    incomeService: _incomeService,
    obligationService: _obligationService,
    expenseService: widget.expenseManagementService,
  );
  late final HouseholdIntelligenceService _intelligence = HouseholdIntelligenceService(
    financialEngine: _engine,
    expenseService: widget.expenseManagementService,
    incomeService: _incomeService,
  );

  FinancialSnapshot? _snapshot;
  FinancialAdvisorSnapshot? _advisorSnapshot;
  AiInsight? _tip;
  bool _loading = true;
  bool _tipLoading = false;
  String? _error;
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  bool _showAllCategories = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final snapshot = await _engine.calculate(
        userId: widget.profile.userId,
        year: _year,
        month: _month,
        currencyCode: widget.profile.currencyCode,
      );
      Map<String, int> categories = const <String, int>{};
      try {
        categories = await widget.expenseManagementService.monthlyActualByCategory(
          year: _year,
          month: _month,
          currencyCode: widget.profile.currencyCode,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _advisorSnapshot = FinancialAdvisorSnapshot(
          financial: snapshot,
          actualByCategory: Map<String, int>.unmodifiable(categories),
        );
        _loading = false;
      });
      unawaited(_loadOpeningTip());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تجهيز الحالة المالية الآن. لم نغيّر أي بيانات محفوظة.';
      });
    }
  }

  Future<void> _loadOpeningTip() async {
    final snapshot = _advisorSnapshot;
    if (snapshot == null || _tipLoading) return;
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final key = 'nus.ai.opening_tip.$dateKey.${widget.profile.currencyCode}';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(key);
    if (cached != null && cached.trim().isNotEmpty) {
      if (mounted) setState(() => _tip = AiInsight(id: 'cached', summary: cached, generatedAt: DateTime.now(), sourceDomain: 'opening_tip'));
      return;
    }
    if (!mounted) return;
    setState(() => _tipLoading = true);
    try {
      final request = snapshot.toAiRequest();
      final insight = await const FinancialAdvisorProvider().generateInsight(
        AiInsightRequest(
          objective: 'Give one practical, evidence-based opening financial tip for the household today. Use only the supplied facts. Do not invent numbers, promises, or trends. Maximum 2 sentences. Do not mention the AI provider.',
          context: request.context,
        ),
      );
      await prefs.setString(key, insight.summary);
      if (mounted) setState(() => _tip = insight);
    } catch (_) {
      // Opening tip is enhancement only and must never block the financial home.
    } finally {
      if (mounted) setState(() => _tipLoading = false);
    }
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
      _tip = null;
    });
    await _load();
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
    await _load();
  }

  Future<void> _openObligations() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ObligationManagementPage(
      userId: widget.profile.userId,
      householdCurrencyCode: widget.profile.currencyCode,
      service: _obligationService,
    )));
    await _load();
  }

  Future<void> _openIntelligence() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HouseholdIntelligencePage(
      service: _intelligence,
      userId: widget.profile.userId,
      year: _year,
      month: _month,
      currencyCode: widget.profile.currencyCode,
    )));
  }

  String _money(int value) => '${_format(value)} ${widget.profile.currencyCode}';

  String _minorMoney(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.profile.currencyCode);
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final raw = value.abs().toString();
    final chunks = <String>[];
    for (var i = raw.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      chunks.insert(0, raw.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  List<MapEntry<String, int>> _topCategories() {
    final items = (_advisorSnapshot?.actualByCategory.entries.toList() ?? <MapEntry<String, int>>[])
      ..removeWhere((entry) => entry.value <= 0)
      ..sort((a, b) => b.value.compareTo(a.value));
    return _showAllCategories ? items : items.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final snapshot = _snapshot;
    final positionMinor = snapshot?.actualPositionMinorUnits ?? 0;
    final positive = positionMinor >= 0;
    final categories = _topCategories();
    final totalActual = categories.fold<int>(0, (sum, item) => sum + item.value);
    return Scaffold(
      backgroundColor: Color.alphaBlend(scheme.primaryContainer.withOpacity(.14), scheme.surface),
      appBar: AppBar(
        title: const Text('NUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3)),
        actions: [
          IconButton(onPressed: _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _openAskNus, tooltip: 'اسأل NUS', icon: const Icon(Icons.auto_awesome_rounded)),
          if (widget.onSignOut != null) IconButton(onPressed: widget.onSignOut, tooltip: 'تسجيل الخروج', icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
            children: [
              _header(context),
              const SizedBox(height: 12),
              _monthSelector(context),
              const SizedBox(height: 12),
              if (_tipLoading || _tip != null) _tipCard(context),
              const SizedBox(height: 12),
              _positionCard(context, positionMinor, positive, snapshot),
              const SizedBox(height: 12),
              _metrics(context, snapshot),
              const SizedBox(height: 14),
              _priorityActions(context),
              const SizedBox(height: 14),
              if (_loading)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
              else if (_error != null)
                _errorCard(context)
              else ...[
                _categoryCard(context, categories, totalActual),
                const SizedBox(height: 14),
                _budgetPressure(context, snapshot),
                const SizedBox(height: 14),
                Card(color: scheme.secondaryContainer, child: ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: const Text('تحليل NUS المالي', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('قراءة أعمق للمخاطر والقدرة المالية من نفس البيانات الفعلية.'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: _openIntelligence,
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Row(children: [
    Container(width: 54, height: 54, decoration: BoxDecoration(gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary]), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x33000000))]), child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 28)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('اقتصاد البيت تحت السيطرة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${widget.profile.householdSize} أفراد · ${widget.profile.currencyCode}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))])),
  ]);

  Widget _monthSelector(BuildContext context) => Row(children: [Expanded(child: Text('الحقيقة أولًا. القرار بعدها.', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))), OutlinedButton.icon(onPressed: _loading ? null : _chooseMonth, icon: const Icon(Icons.calendar_month_rounded, size: 18), label: Text('${_month.toString().padLeft(2, '0')}/$_year'))]);

  Widget _tipCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(color: scheme.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.lightbulb_rounded, color: scheme.onTertiaryContainer), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('نصيحة NUS', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onTertiaryContainer)), const SizedBox(height: 5), _tipLoading ? const LinearProgressIndicator() : Text(_tip?.summary ?? '', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer))]))])));
  }

  Widget _positionCard(BuildContext context, int positionMinor, bool positive, FinancialSnapshot? snapshot) {
    final scheme = Theme.of(context).colorScheme;
    final afterObligations = snapshot?.positionAfterObligations ?? 0;
    return Card(clipBehavior: Clip.antiAlias, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: positive ? [scheme.primaryContainer, scheme.surface] : [scheme.errorContainer, scheme.surface], begin: Alignment.topRight, end: Alignment.bottomLeft)), padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.speed_rounded), const SizedBox(width: 7), const Text('المركز المالي الفعلي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Icon(positive ? Icons.check_circle_rounded : Icons.warning_rounded)]),
      const SizedBox(height: 7),
      Text(_minorMoney(positionMinor), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
      Text('الدخل الفعلي ناقص المصروفات الفعلية للشهر المحدد.', style: TextStyle(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _smallMetric('دخل الشهر', _money(snapshot?.monthlyIncome ?? 0))), Expanded(child: _smallMetric('بعد الالتزامات', _money(afterObligations)))]),
    ])));
  }

  Widget _smallMetric(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]);

  Widget _metrics(BuildContext context, FinancialSnapshot? snapshot) => GridView.count(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.58, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
    _metric('الدخل', _money(snapshot?.monthlyIncome ?? 0), Icons.south_west_rounded),
    _metric('الالتزامات', _money(snapshot?.monthlyObligations ?? 0), Icons.lock_outline_rounded),
    _metric('المصروف الفعلي', snapshot == null ? '—' : _minorMoney(snapshot.actualExpensesMinorUnits), Icons.payments_outlined),
    _metric('المتكرر المتوقع', snapshot == null ? '—' : _minorMoney(snapshot.expectedRecurringExpensesMinorUnits), Icons.repeat_rounded),
  ]);

  Widget _metric(String title, String value, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(blurRadius: 20, offset: Offset(0, 8), color: Color(0x12000000))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 21), const Spacer(), Text(title, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]));
  }

  Widget _priorityActions(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
    Expanded(child: _action('اسأل NUS', Icons.auto_awesome_rounded, _openAskNus)),
    Expanded(child: _action('الدخل', Icons.account_balance_wallet_outlined, _openIncome)),
    Expanded(child: _action('الالتزامات', Icons.receipt_long_rounded, _openObligations)),
  ])));

  Widget _action(String title, IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4), child: Column(children: [Icon(icon, size: 25), const SizedBox(height: 5), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))])));

  Widget _categoryCard(BuildContext context, List<MapEntry<String, int>> entries, int total) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text('خريطة الإنفاق الفعلي', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), if (entries.length >= 5) TextButton(onPressed: () => setState(() => _showAllCategories = !_showAllCategories), child: Text(_showAllCategories ? 'أقل' : 'كل الفئات'))]), const SizedBox(height: 12), if (total <= 0) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد مصروفات فعلية مسجلة كفاية لعرض توزيع صادق حتى الآن.'))) else Row(children: [SizedBox(width: 142, height: 142, child: CustomPaint(painter: _DonutPainter(entries, total), child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('الإجمالي', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), Text(_minorMoney(total), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))])))), const SizedBox(width: 14), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [for (final entry in entries) _legend(context, entry, total)]))])]));

  Widget _legend(BuildContext context, MapEntry<String, int> entry, int total) { final ratio = entry.value / total; return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))), SizedBox(width: 70, child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 8))), const SizedBox(width: 8), SizedBox(width: 34, child: Text('${(ratio * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)))])); }

  Widget _budgetPressure(BuildContext context, FinancialSnapshot? snapshot) {
    if (snapshot == null) return const SizedBox.shrink();
    final committedMinor = snapshot.monthlyObligationsMinorUnits + snapshot.expectedRecurringExpensesMinorUnits;
    final incomeMinor = snapshot.monthlyIncomeMinorUnits;
    final ratio = incomeMinor <= 0 ? 0.0 : (committedMinor / incomeMinor).clamp(0.0, 1.0);
    final remainingMinor = incomeMinor - committedMinor;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ضغط الميزانية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), const Text('الجزء الملتزم من الدخل قبل المصروفات الجديدة.'), const SizedBox(height: 12), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 12)), const SizedBox(height: 9), Row(children: [Expanded(child: Text('${(ratio * 100).round()}% ملتزم أو متوقع', style: const TextStyle(fontWeight: FontWeight.w900))), Text(_minorMoney(remainingMinor), style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 4), Text('الباقي هنا تقديري محاسبي وليس رصيدًا نقديًا متاحًا.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))])));
  }

  Widget _errorCard(BuildContext context) => Card(color: Theme.of(context).colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline_rounded), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('تعذر تجهيز اللوحة المالية', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('$_error'), const SizedBox(height: 8), OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة'))]))]));
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.entries, this.total);
  final List<MapEntry<String, int>> entries;
  final int total;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 10;
    final stroke = radius * .29;
    var start = -3.141592653589793 / 2;
    const palette = <Color>[Color(0xFF4F46E5), Color(0xFF0891B2), Color(0xFF16A34A), Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF0F766E), Color(0xFF64748B)];
    for (var i = 0; i < entries.length; i++) {
      final sweep = entries[i].value / total * 2 * 3.141592653589793;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = palette[i % palette.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.total != total || oldDelegate.entries != entries;
}
