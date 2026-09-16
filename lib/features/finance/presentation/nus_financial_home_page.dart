import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_insight.dart';
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
  late final IncomeSourceService _incomeService = const IncomeSourceService(
    repository: SupabaseIncomeSourceRepository(),
  );
  late final ObligationService _obligationService = const ObligationService(
    repository: SupabaseObligationRepository(),
  );
  late final FinancialEngine _engine = FinancialEngine(
    incomeService: _incomeService,
    obligationService: _obligationService,
    expenseService: widget.expenseManagementService,
  );
  late final HouseholdIntelligenceService _intelligence =
      HouseholdIntelligenceService(
    financialEngine: _engine,
    expenseService: widget.expenseManagementService,
    incomeService: _incomeService,
  );
  late final FinancialAdvisorProvider _advisor = const FinancialAdvisorProvider();

  FinancialSnapshot? _snapshot;
  FinancialAdvisorSnapshot? _advisorSnapshot;
  AiInsight? _openingTip;
  String? _error;
  bool _loading = true;
  bool _tipLoading = false;
  bool _showAllCategories = false;
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final FinancialSnapshot snapshot = await _engine.calculate(
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
      } catch (_) {
        // Category detail is optional; totals remain authoritative.
      }
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
    final FinancialAdvisorSnapshot? snapshot = _advisorSnapshot;
    if (snapshot == null || _tipLoading) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final String key = 'nus.ai.opening_tip.v2.${widget.profile.userId}.$dateKey.$_year.${_month.toString().padLeft(2, '0')}.${widget.profile.currencyCode}';
    final String? cached = prefs.getString(key);
    if (cached != null && cached.trim().isNotEmpty) {
      if (mounted) {
        setState(() {
          _openingTip = AiInsight(
            id: 'cached',
            summary: cached,
            generatedAt: DateTime.now(),
            sourceDomain: 'opening_tip',
          );
        });
      }
      return;
    }
    if (mounted) setState(() => _tipLoading = true);
    try {
      final AiInsightRequest request = snapshot.toAiRequest();
      final AiInsight insight = await _advisor.generateInsight(
        AiInsightRequest(
          objective:
              'اكتب نصيحة مالية عملية ومختصرة لرب الأسرة اليوم باللهجة المصرية الطبيعية. استخدم الحقائق المرسلة فقط. لا تخترع أرقامًا أو وعودًا أو اتجاهات. جملتان كحد أقصى. لا تذكر اسم مزود الذكاء الاصطناعي.',
          context: request.context,
        ),
      );
      await prefs.setString(key, insight.summary);
      if (mounted) setState(() => _openingTip = insight);
    } catch (_) {
      // Dashboard remains useful without AI.
    } finally {
      if (mounted) setState(() => _tipLoading = false);
    }
  }

  Future<void> _chooseMonth() async {
    final DateTime? picked = await showDatePicker(
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
      _openingTip = null;
    });
    await _load();
  }

  Future<void> _openAskNus() async {
    final FinancialAdvisorSnapshot? snapshot = _advisorSnapshot;
    if (snapshot == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AskNusPage(snapshot: snapshot)),
    );
  }

  Future<void> _openIncome() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => IncomeManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _incomeService,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openObligations() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ObligationManagementPage(
          userId: widget.profile.userId,
          householdCurrencyCode: widget.profile.currencyCode,
          service: _obligationService,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openIntelligence() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => HouseholdIntelligencePage(
          service: _intelligence,
          userId: widget.profile.userId,
          year: _year,
          month: _month,
          currencyCode: widget.profile.currencyCode,
        ),
      ),
    );
  }

  String _majorMoney(int value) => '${_format(value)} ${widget.profile.currencyCode}';

  String _minorMoney(int minorUnits) {
    final CurrencyMetadata metadata = CurrencyRegistry.get(widget.profile.currencyCode);
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final int absolute = minorUnits.abs();
    final int whole = absolute ~/ metadata.scale;
    final String fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    final String sign = minorUnits < 0 ? '-' : '';
    return '$sign${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final String raw = value.abs().toString();
    final List<String> chunks = <String>[];
    for (int i = raw.length; i > 0; i -= 3) {
      final int start = i > 3 ? i - 3 : 0;
      chunks.insert(0, raw.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${chunks.join(',')}';
  }

  List<MapEntry<String, int>> _allCategories() {
    final List<MapEntry<String, int>> items =
        (_advisorSnapshot?.actualByCategory.entries.toList() ?? <MapEntry<String, int>>[])
          ..removeWhere((MapEntry<String, int> item) => item.value <= 0)
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));
    return items;
  }

  List<MapEntry<String, int>> _chartCategories(List<MapEntry<String, int>> allCategories) {
    if (_showAllCategories || allCategories.length <= 5) return allCategories;
    final List<MapEntry<String, int>> visible = allCategories.take(5).toList(growable: true);
    final int hiddenTotal = allCategories.skip(5).fold<int>(0, (int sum, MapEntry<String, int> item) => sum + item.value);
    if (hiddenTotal > 0) visible.add(MapEntry<String, int>('أخرى', hiddenTotal));
    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final FinancialSnapshot? snapshot = _snapshot;
    final List<MapEntry<String, int>> allCategories = _allCategories();
    final List<MapEntry<String, int>> chartCategories = _chartCategories(allCategories);
    final int total = allCategories.fold<int>(0, (int sum, MapEntry<String, int> item) => sum + item.value);
    final int positionMinor = snapshot?.actualPositionMinorUnits ?? 0;

    return Scaffold(
      backgroundColor: Color.alphaBlend(
        scheme.primaryContainer.withValues(alpha: .12),
        scheme.surface,
      ),
      appBar: AppBar(
        title: const Text('NUS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        actions: <Widget>[
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث'),
          IconButton(onPressed: _openAskNus, icon: const Icon(Icons.auto_awesome_rounded), tooltip: 'اسأل NUS'),
          if (widget.onSignOut != null)
            IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded), tooltip: 'تسجيل الخروج'),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: <Widget>[
              Text('اقتصاد البيت تحت السيطرة', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${widget.profile.householdSize} أفراد · ${widget.profile.currencyCode}', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(child: Text('الحقيقة أولًا. القرار بعدها.', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant))),
                  OutlinedButton.icon(onPressed: _loading ? null : _chooseMonth, icon: const Icon(Icons.calendar_month_rounded, size: 18), label: Text('${_month.toString().padLeft(2, '0')}/$_year')),
                ],
              ),
              if (_tipLoading || _openingTip != null) ...<Widget>[const SizedBox(height: 10), _tipCard(context)],
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(children: <Widget>[const Icon(Icons.speed_rounded), const SizedBox(width: 8), const Text('المركز المالي الفعلي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Icon(positionMinor >= 0 ? Icons.check_circle_rounded : Icons.warning_rounded)]),
                      const SizedBox(height: 6),
                      Text(_minorMoney(positionMinor), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900)),
                      Text('الدخل الفعلي ناقص المصروفات الفعلية للشهر المحدد.', style: TextStyle(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 14),
                      Row(children: <Widget>[
                        Expanded(child: _mini('دخل الشهر', _majorMoney(snapshot?.monthlyIncome ?? 0))),
                        Expanded(child: _mini('بعد الالتزامات', _majorMoney(snapshot?.positionAfterObligations ?? 0))),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: <Widget>[
                  _metric('الدخل', _majorMoney(snapshot?.monthlyIncome ?? 0), Icons.south_west_rounded),
                  _metric('الالتزامات', _majorMoney(snapshot?.monthlyObligations ?? 0), Icons.lock_outline_rounded),
                  _metric('المصروف الفعلي', snapshot == null ? '—' : _minorMoney(snapshot.actualExpensesMinorUnits), Icons.payments_outlined),
                  _metric('المتكرر المتوقع', snapshot == null ? '—' : _minorMoney(snapshot.expectedRecurringExpensesMinorUnits), Icons.repeat_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: <Widget>[
                    Expanded(child: _action('اسأل NUS', Icons.auto_awesome_rounded, _openAskNus)),
                    Expanded(child: _action('الدخل', Icons.account_balance_wallet_outlined, _openIncome)),
                    Expanded(child: _action('الالتزامات', Icons.receipt_long_rounded, _openObligations)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())))
              else if (_error != null)
                _errorCard(context)
              else ...<Widget>[
                _categoryCard(context, chartCategories, total, allCategories.length > 5),
                const SizedBox(height: 12),
                _budgetCard(context, snapshot),
                const SizedBox(height: 12),
                Card(
                  color: scheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.insights_rounded),
                    title: const Text('تحليل NUS المالي', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('قراءة أعمق للمخاطر والقدرة المالية من نفس البيانات الفعلية.'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: _openIntelligence,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipCard(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Icon(Icons.lightbulb_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('نصيحة NUS — تحليل حي', style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onTertiaryContainer)),
            const SizedBox(height: 5),
            if (_tipLoading) const LinearProgressIndicator() else Text(_openingTip?.summary ?? '', style: TextStyle(height: 1.45, fontWeight: FontWeight.w600, color: scheme.onTertiaryContainer)),
          ])),
        ]),
      ),
    );
  }

  Widget _mini(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
  ]);

  Widget _metric(String title, String value, IconData icon) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(18), boxShadow: const <BoxShadow>[BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x12000000))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, size: 21),
        const Spacer(),
        Text(title, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _action(String title, IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
      child: Column(children: <Widget>[Icon(icon, size: 25), const SizedBox(height: 5), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))]),
    ),
  );

  Widget _categoryCard(BuildContext context, List<MapEntry<String, int>> entries, int total, bool canExpand) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            const Expanded(child: Text('خريطة الإنفاق الفعلي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
            if (canExpand)
              TextButton(onPressed: () => setState(() => _showAllCategories = !_showAllCategories), child: Text(_showAllCategories ? 'أقل' : 'كل الفئات')),
          ]),
          const SizedBox(height: 10),
          if (total <= 0)
            const Padding(padding: EdgeInsets.all(18), child: Center(child: Text('لا توجد مصروفات فعلية مسجلة تكفي لعرض توزيع صادق حتى الآن.', textAlign: TextAlign.center)))
          else
            Row(children: <Widget>[
              SizedBox(width: 135, height: 135, child: CustomPaint(painter: _DonutPainter(entries: entries, total: total), child: Center(child: Text(_minorMoney(total), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))))),
              const SizedBox(width: 14),
              Expanded(child: Column(children: entries.map((MapEntry<String, int> entry) => _legend(context, entry, total)).toList(growable: false))),
            ]),
        ]),
      ),
    );
  }

  Widget _legend(BuildContext context, MapEntry<String, int> entry, int total) {
    final double ratio = entry.value / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Expanded(child: Text(entry.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${(ratio * 100).round()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 7)),
      ]),
    );
  }

  Widget _budgetCard(BuildContext context, FinancialSnapshot? snapshot) {
    if (snapshot == null) return const SizedBox.shrink();
    final int committedMinor = snapshot.monthlyObligationsMinorUnits + snapshot.expectedRecurringExpensesMinorUnits;
    final int incomeMinor = snapshot.monthlyIncomeMinorUnits;
    final double ratio = incomeMinor <= 0 ? 0 : (committedMinor / incomeMinor).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const Text('ضغط الميزانية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('الجزء الملتزم أو المتوقع من الدخل قبل المصروفات الجديدة.'),
          const SizedBox(height: 11),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 11)),
          const SizedBox(height: 8),
          Text('${(ratio * 100).round()}% ملتزم أو متوقع', style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('هذا المؤشر حسابي وليس رصيدًا نقديًا متاحًا.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _errorCard(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('تعذر تجهيز اللوحة المالية', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(_error ?? ''),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
      ]),
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.entries, required this.total});
  final List<MapEntry<String, int>> entries;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 8;
    final double stroke = radius * .28;
    double start = -3.141592653589793 / 2;
    const List<Color> palette = <Color>[
      Color(0xFF4F46E5), Color(0xFF0891B2), Color(0xFF16A34A), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF0F766E), Color(0xFF64748B),
    ];
    for (int index = 0; index < entries.length; index++) {
      final double sweep = entries[index].value / total * 2 * 3.141592653589793;
      final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = palette[index % palette.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.total != total || oldDelegate.entries != entries;
}
