import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../expenses/application/expense_management_service.dart';
import '../../expenses/data/supabase_expense_repository.dart';
import '../../expenses/data/supabase_recurring_expense_repository.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../expenses/domain/expense_category.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import '../application/cashflow_forecast_service.dart';
import '../application/financial_engine.dart';
import '../application/household_intelligence_service.dart';
import 'cashflow_forecast_page.dart';
import 'financial_goals_page.dart';

class HouseholdIntelligencePage extends StatefulWidget {
  const HouseholdIntelligencePage({
    super.key,
    required this.service,
    required this.userId,
    required this.year,
    required this.month,
    required this.currencyCode,
  });

  final HouseholdIntelligenceService service;
  final String userId;
  final int year;
  final int month;
  final String currencyCode;

  @override
  State<HouseholdIntelligencePage> createState() => _HouseholdIntelligencePageState();
}

class _HouseholdIntelligencePageState extends State<HouseholdIntelligencePage> {
  HouseholdIntelligenceSnapshot? _snapshot;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final snapshot = await widget.service.analyze(
        userId: widget.userId,
        year: widget.year,
        month: widget.month,
        currencyCode: widget.currencyCode,
      );
      if (!mounted) return;
      setState(() { _snapshot = snapshot; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error; _loading = false; });
    }
  }

  void _openGoals() {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => FinancialGoalsPage(
        userId: widget.userId,
        householdCurrencyCode: widget.currencyCode,
      ),
    ));
  }

  void _openForecast() {
    final expenses = ExpenseManagementService(
      expenseRepository: const SupabaseExpenseRepository(),
      recurringRepository: const SupabaseRecurringExpenseRepository(),
    );
    final engine = FinancialEngine(
      incomeService: IncomeSourceService(repository: const SupabaseIncomeSourceRepository()),
      obligationService: const ObligationService(repository: SupabaseObligationRepository()),
      expenseService: expenses,
    );
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CashflowForecastPage(
        userId: widget.userId,
        year: widget.year,
        month: widget.month,
        currencyCode: widget.currencyCode,
        service: CashflowForecastService(financialEngine: engine),
      ),
    ));
  }

  HouseholdInsight? _first(HouseholdIntelligenceSnapshot snapshot, String type) {
    for (final insight in snapshot.insights) {
      if (insight.type == type) return insight;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقارير NUS', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
            children: <Widget>[
              _hero(context),
              const SizedBox(height: 12),
              if (_loading)
                const Card(child: Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())))
              else if (_error != null)
                Card(
                  key: const ValueKey<String>('household-intelligence-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                      const Text('تعذر تحميل التقرير الآن.', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('لم يتم اختراع أي أرقام. البيانات الحالية بقيت بدون تعديل.'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                    ]),
                  ),
                )
              else if (snapshot != null)
                ..._report(context, snapshot),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: <Color>[scheme.primary, scheme.secondary]),
        boxShadow: const <BoxShadow>[BoxShadow(blurRadius: 24, offset: Offset(0, 10), color: Color(0x22000000))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28)),
          const SizedBox(width: 12),
          const Expanded(child: Text('لوحة تقارير NUS', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 10),
        Text('افهم الصورة كاملة من البيانات المسجلة فعلًا.', style: TextStyle(color: Colors.white.withValues(alpha: .92), height: 1.45)),
        const SizedBox(height: 12),
        Row(children: <Widget>[
          Expanded(child: FilledButton.icon(key: const ValueKey<String>('financial-goals-section-entry'), onPressed: _openGoals, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: scheme.primary), icon: const Icon(Icons.flag_rounded), label: const Text('الأهداف المالية'))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(key: const ValueKey<String>('cashflow-forecast-entry'), onPressed: _loading ? null : _openForecast, style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: .65))), icon: const Icon(Icons.timeline_rounded), label: const Text('توقع السيولة'))),
        ]),
      ]),
    );
  }

  List<Widget> _report(BuildContext context, HouseholdIntelligenceSnapshot snapshot) {
    final trend = _first(snapshot, 'monthly_trend');
    final highest = _first(snapshot, 'highest_category');
    final recurring = _first(snapshot, 'recurring_vs_actual');
    final obligation = _first(snapshot, 'obligation_burden');
    final comparison = _first(snapshot, 'unusual_months');
    final changes = snapshot.insights.where((i) => i.type == 'category_increasing' || i.type == 'category_decreasing').take(4).toList(growable: false);
    final insufficient = snapshot.insights.where((i) => i.dataState == HouseholdDataState.insufficient).take(4).toList(growable: false);

    return <Widget>[
      if (trend != null) _trendCard(context, trend),
      const SizedBox(height: 12),
      _kpiGrid(context, highest, obligation, recurring),
      const SizedBox(height: 12),
      if (comparison != null) _section(context, const ValueKey<String>('monthly-comparison-card'), 'مقارنة الأشهر', Icons.compare_arrows_rounded, _insight(context, comparison, series: true)),
      if (changes.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _section(context, const ValueKey<String>('category-changes-card'), 'بنود بتزيد أو بتقل', Icons.swap_vert_rounded, Column(children: changes.map((i) => _insight(context, i, compact: true)).toList(growable: false))),
      ],
      const SizedBox(height: 12),
      _section(context, const ValueKey<String>('insufficient-data-card'), 'ما نعرفه وما لا نعرفه', Icons.verified_outlined, insufficient.isEmpty
          ? const Text('البيانات الحالية كافية لإظهار المؤشرات الأساسية.')
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: insufficient.map((i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('• ${i.title}: ${i.explanation}'))).toList(growable: false))),
    ];
  }

  Widget _trendCard(BuildContext context, HouseholdInsight trend) {
    final values = trend.periodValues;
    return _section(
      context,
      const ValueKey<String>('spending-trend-card'),
      'اتجاه المصروفات',
      Icons.stacked_line_chart_rounded,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        const Text('عرض بصري تاريخي بعمق منظور 3D — من السجل الفعلي فقط.'),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: CustomPaint(
            painter: _PerspectiveChartPainter(
              values: values.map((item) => item.valueMinorUnits.abs().toDouble()).toList(growable: false),
              labels: values.map((item) => item.periodLabel).toList(growable: false),
              primary: Theme.of(context).colorScheme.primary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        Text(trend.explanation, style: const TextStyle(height: 1.45)),
      ]),
    );
  }

  Widget _kpiGrid(BuildContext context, HouseholdInsight? highest, HouseholdInsight? obligation, HouseholdInsight? recurring) {
    final scheme = Theme.of(context).colorScheme;
    final income = obligation?.comparisonValueMinorUnits ?? 0;
    final obligationValue = obligation?.valueMinorUnits ?? 0;
    final recurringValue = recurring?.comparisonValueMinorUnits ?? 0;
    final pressure = income <= 0 ? 0 : (obligationValue.abs() / income.abs()).clamp(0.0, 1.0);
    final category = highest?.categoryCode == null ? '—' : ExpenseCategories.labelsAr[highest!.categoryCode!] ?? highest.categoryCode!;
    final categoryAmount = highest?.valueMinorUnits == null ? '—' : _money(highest!.valueMinorUnits!);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.18,
      children: <Widget>[
        _metricCard(context, 'أعلى إنفاق', category, categoryAmount, Icons.pie_chart_rounded),
        _metricCard(context, 'ضغط الالتزامات', '${(pressure * 100).round()}%', _money(obligationValue), Icons.speed_rounded),
        _metricCard(context, 'المتكرر المتوقع', _money(recurringValue), 'ليس مصروفًا فعليًا', Icons.repeat_rounded),
        _metricCard(context, 'جودة البيانات', 'حقيقية', 'بدون تخمين أو تحويل عملات', Icons.verified_rounded),
      ],
    );
  }

  Widget _metricCard(BuildContext context, String title, String value, String subtitle, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: const <BoxShadow>[BoxShadow(blurRadius: 18, offset: Offset(0, 7), color: Color(0x10000000))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Icon(icon, size: 22),
        const Spacer(),
        Text(title, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _section(BuildContext context, Key key, String title, IconData icon, Widget child) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[CircleAvatar(child: Icon(icon)), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }

  Widget _insight(BuildContext context, HouseholdInsight insight, {bool series = false, bool compact = false}) {
    final category = insight.categoryCode == null ? null : ExpenseCategories.labelsAr[insight.categoryCode!] ?? insight.categoryCode!;
    final value = insight.valueMinorUnits == null ? null : _money(insight.valueMinorUnits!);
    final comparison = insight.comparisonValueMinorUnits == null ? null : _money(insight.comparisonValueMinorUnits!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      if (category != null) Text(category, style: const TextStyle(fontWeight: FontWeight.w900)),
      Text(insight.explanation, style: const TextStyle(height: 1.4)),
      if (value != null) Text('القيمة: $value', style: const TextStyle(fontWeight: FontWeight.w800)),
      if (comparison != null) Text('المقارنة: $comparison', style: const TextStyle(fontWeight: FontWeight.w800)),
      if (series && insight.periodValues.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: insight.periodValues.take(6).map((p) => Chip(label: Text('${p.periodLabel}: ${_money(p.valueMinorUnits)}'))).toList(growable: false)),
      ],
      if (insight.dataState == HouseholdDataState.insufficient && !compact) const Padding(padding: EdgeInsets.only(top: 6), child: Text('البيانات غير كافية للحكم الآمن.')),
    ]);
  }

  String _money(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    if (metadata.exponent == 0) return '${_format(minorUnits)} ${metadata.code}';
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = (absolute % metadata.scale).toString().padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final raw = value.abs().toString();
    final parts = <String>[];
    for (var i = raw.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, raw.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${parts.join(',')}';
  }
}

class _PerspectiveChartPainter extends CustomPainter {
  const _PerspectiveChartPainter({required this.values, required this.labels, required this.primary});
  final List<double> values;
  final List<String> labels;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.reduce(math.max);
    if (maxValue <= 0) return;
    final baseline = size.height - 28;
    final chartHeight = size.height - 52;
    final gap = 9.0;
    final depth = 8.0;
    final barWidth = math.max(18.0, (size.width - gap * (values.length + 1)) / values.length);

    canvas.drawLine(Offset(0, baseline), Offset(size.width, baseline), Paint()..color = Colors.grey.withValues(alpha: .25));
    for (var i = 0; i < values.length; i++) {
      final x = gap + i * (barWidth + gap);
      final h = chartHeight * values[i] / maxValue;
      final top = baseline - h;
      final front = RRect.fromRectAndRadius(Rect.fromLTWH(x, top, barWidth, h), const Radius.circular(6));
      final side = Path()..moveTo(x + barWidth, top + 6)..lineTo(x + barWidth + depth, top - 2)..lineTo(x + barWidth + depth, baseline - 2)..lineTo(x + barWidth, baseline)..close();
      final cap = Path()..moveTo(x, top)..lineTo(x + depth, top - 7)..lineTo(x + barWidth + depth, top - 2)..lineTo(x + barWidth, top + 6)..close();
      canvas.drawRRect(front.shift(const Offset(0, 5)), Paint()..color = Colors.black.withValues(alpha: .12)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawRRect(front, Paint()..color = primary);
      canvas.drawPath(side, Paint()..color = primary.withValues(alpha: .68));
      canvas.drawPath(cap, Paint()..color = primary.withValues(alpha: .92));

      if (i < labels.length) {
        final text = TextPainter(
          text: TextSpan(text: labels[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
          textDirection: TextDirection.rtl,
          maxLines: 1,
          ellipsis: '…',
        )..layout(maxWidth: barWidth + depth + 8);
        text.paint(canvas, Offset(x - 2, baseline + 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PerspectiveChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.labels != labels || oldDelegate.primary != primary;
}
