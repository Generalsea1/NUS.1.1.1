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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await widget.service.analyze(
        userId: widget.userId,
        year: widget.year,
        month: widget.month,
        currencyCode: widget.currencyCode,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _openGoals() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FinancialGoalsPage(
          userId: widget.userId,
          householdCurrencyCode: widget.currencyCode,
        ),
      ),
    );
  }

  void _openCashflowForecast() {
    final expenseService = ExpenseManagementService(
      expenseRepository: const SupabaseExpenseRepository(),
      recurringRepository: const SupabaseRecurringExpenseRepository(),
    );
    final financialEngine = FinancialEngine(
      incomeService: IncomeSourceService(
        repository: const SupabaseIncomeSourceRepository(),
      ),
      obligationService: const ObligationService(
        repository: SupabaseObligationRepository(),
      ),
      expenseService: expenseService,
    );
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CashflowForecastPage(
          userId: widget.userId,
          year: widget.year,
          month: widget.month,
          currencyCode: widget.currencyCode,
          service: CashflowForecastService(financialEngine: financialEngine),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ذكاء البيت')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'ذكاء البيت',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تحليل موثوق لبياناتك المسجلة فقط — بدون توقعات أو تخمينات.',
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('financial-goals-section-entry'),
                      onPressed: _openGoals,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('الأهداف المالية'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey<String>('cashflow-forecast-entry'),
                      onPressed: _loading ? null : _openCashflowForecast,
                      icon: const Icon(Icons.trending_up_rounded),
                      label: const Text('توقع السيولة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                Card(
                  key: const ValueKey<String>('household-intelligence-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تعذر تحميل ذكاء البيت الآن.'),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._buildInsights(context, _snapshot!),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInsights(
    BuildContext context,
    HouseholdIntelligenceSnapshot snapshot,
  ) {
    final widgets = <Widget>[];
    final sufficient = snapshot.insights
        .where((i) => i.dataState == HouseholdDataState.sufficient)
        .toList();
    final insufficient = snapshot.insights
        .where((i) => i.dataState == HouseholdDataState.insufficient)
        .toList();

    final highest = _first(snapshot, 'highest_category');
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('highest-spending-card'),
        title: 'أعلى بنود الإنفاق',
        icon: Icons.bar_chart_rounded,
        child: highest == null
            ? _insufficientText('مفيش بيانات كفاية.')
            : _insightBody(highest, context),
      ),
    );

    final trend = _first(snapshot, 'monthly_trend');
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('spending-trend-card'),
        title: 'اتجاه المصروفات',
        icon: Icons.show_chart_rounded,
        child: trend == null
            ? _insufficientText('مفيش بيانات كفاية.')
            : _insightBody(trend, context, showSeries: true),
      ),
    );

    final recurring = _first(snapshot, 'recurring_vs_actual');
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('recurring-burden-card'),
        title: 'المصروفات المتكررة',
        icon: Icons.repeat_rounded,
        child: recurring == null
            ? _insufficientText('مفيش بيانات كفاية.')
            : _insightBody(recurring, context),
      ),
    );

    final obligation = _first(snapshot, 'obligation_burden');
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('obligation-burden-card'),
        title: 'ضغط الالتزامات',
        icon: Icons.event_note_rounded,
        child: obligation == null
            ? _insufficientText('مفيش بيانات كفاية.')
            : _insightBody(obligation, context),
      ),
    );

    final comparison = _first(snapshot, 'unusual_months');
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('monthly-comparison-card'),
        title: 'مقارنة الأشهر',
        icon: Icons.compare_arrows_rounded,
        child: comparison == null
            ? _insufficientText('مفيش بيانات كفاية.')
            : _insightBody(comparison, context, showSeries: true),
      ),
    );

    final categoryChanges = sufficient
        .where(
          (insight) =>
              insight.type == 'category_increasing' ||
              insight.type == 'category_decreasing',
        )
        .take(4)
        .toList(growable: false);
    if (categoryChanges.isNotEmpty) {
      widgets.add(
        _sectionCard(
          context,
          key: const ValueKey<String>('category-changes-card'),
          title: 'بنود بتزيد أو بتقل',
          icon: Icons.swap_vert_rounded,
          child: Column(
            children: [
              for (final insight in categoryChanges)
                _insightBody(insight, context, compact: true),
            ],
          ),
        ),
      );
    }

    final stability = _first(snapshot, 'income_stability');
    final messages = insufficient
        .where(
          (i) =>
              i.type == 'income_stability' ||
              i.dataState == HouseholdDataState.insufficient,
        )
        .toList(growable: false);
    widgets.add(
      _sectionCard(
        context,
        key: const ValueKey<String>('insufficient-data-card'),
        title: 'بيانات غير كافية',
        icon: Icons.info_outline_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messages.isEmpty && stability != null)
              _insightBody(stability, context)
            else
              for (final insight in messages.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('• ${insight.title}: ${insight.explanation}'),
                ),
          ],
        ),
      ),
    );

    return [
      for (var i = 0; i < widgets.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        widgets[i],
      ],
    ];
  }

  HouseholdInsight? _first(
    HouseholdIntelligenceSnapshot snapshot,
    String type,
  ) {
    for (final insight in snapshot.insights) {
      if (insight.type == type) return insight;
    }
    return null;
  }

  Widget _sectionCard(
    BuildContext context, {
    required Key key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _insightBody(
    HouseholdInsight insight,
    BuildContext context, {
    bool showSeries = false,
    bool compact = false,
  }) {
    final label = insight.categoryCode == null
        ? null
        : ExpenseCategories.labelsAr[insight.categoryCode!] ??
            insight.categoryCode!;
    final value = insight.valueMinorUnits == null
        ? null
        : _minorMoney(insight.valueMinorUnits!);
    final comparison = insight.comparisonValueMinorUnits == null
        ? null
        : _minorMoney(insight.comparisonValueMinorUnits!);
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          Text(insight.explanation),
          const SizedBox(height: 8),
          if (value != null)
            Text(
              'القيمة المسجلة: $value',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if (comparison != null)
            Text(
              'المقارنة: $comparison',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          if (insight.dataState == HouseholdDataState.insufficient)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('البيانات غير كافية للحكم الآمن.'),
            ),
          if (showSeries && insight.periodValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final point in insight.periodValues)
              Text(
                '${point.periodLabel}: ${_minorMoney(point.valueMinorUnits)}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _insufficientText(String text) => Text(text);

  String _minorMoney(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    if (metadata.exponent == 0) {
      return '${_format(minorUnits)} ${metadata.code}';
    }
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = (absolute % metadata.scale)
        .toString()
        .padLeft(metadata.exponent, '0');
    return '${minorUnits < 0 ? '-' : ''}${_format(whole)}.$fraction ${metadata.code}';
  }

  String _format(int value) {
    final text = value.abs().toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${parts.join(',')}';
  }
}
