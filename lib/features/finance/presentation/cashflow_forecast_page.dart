import 'package:flutter/material.dart';

import '../application/affordability_service.dart';
import '../application/cashflow_forecast_service.dart';
import '../application/financial_engine.dart';
import '../domain/cashflow_forecast.dart';
import '../../expenses/application/expense_management_service.dart';
import '../../expenses/data/supabase_expense_repository.dart';
import '../../expenses/data/supabase_recurring_expense_repository.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import 'affordability_page.dart';

class CashflowForecastPage extends StatefulWidget {
  const CashflowForecastPage({
    super.key,
    required this.userId,
    required this.year,
    required this.month,
    required this.currencyCode,
    required this.service,
  });

  final String userId;
  final int year;
  final int month;
  final String currencyCode;
  final CashflowForecastService service;

  @override
  State<CashflowForecastPage> createState() => _CashflowForecastPageState();
}

class _CashflowForecastPageState extends State<CashflowForecastPage> {
  CashflowForecast? _forecast;
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
      final forecast = await widget.service.forecast(
        userId: widget.userId,
        year: widget.year,
        month: widget.month,
        currencyCode: widget.currencyCode,
      );
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _forecast = null;
        _error = error;
        _loading = false;
      });
    }
  }

  void _openAffordability() {
    final expenseService = ExpenseManagementService(
      expenseRepository: const SupabaseExpenseRepository(),
      recurringRepository: const SupabaseRecurringExpenseRepository(),
    );
    final engine = FinancialEngine(
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
        builder: (_) => AffordabilityPage(
          userId: widget.userId,
          year: widget.year,
          month: widget.month,
          currencyCode: widget.currencyCode,
          service: AffordabilityService(financialEngine: engine),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;
    return Scaffold(
      appBar: AppBar(title: const Text('توقع السيولة')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'الفلوس رايحة لفين خلال الشهور الجاية؟',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'تقدير حسابي مبني على الدخل والالتزامات والإنفاق الفعلي المسجل. مش توقع لدخل جديد، ومش ضمان للمستقبل.',
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Card(
                  key: ValueKey<String>('cashflow-forecast-loading'),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                Card(
                  key: const ValueKey<String>('cashflow-forecast-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('تعذر حساب توقع السيولة الآن.'),
                        const SizedBox(height: 8),
                        const Text('راجع بيانات الدخل والمصروفات والالتزامات ثم جرّب مرة تانية.'),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (forecast != null) ...[
                _statusCard(context, forecast),
                const SizedBox(height: 12),
                Card(
                  key: const ValueKey<String>('cashflow-forecast-summary'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المتوسط التاريخي المستخدم',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(_money(forecast.averageDiscretionaryExpenseMinorUnits)),
                        const SizedBox(height: 6),
                        Text(
                          'عدد الشهور التي دخلت في المتوسط: ${forecast.historyMonthsUsed}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const ValueKey<String>('open-affordability'),
                          onPressed: _openAffordability,
                          icon: const Icon(Icons.rule_rounded),
                          label: const Text('هل أقدر أعمل ده؟'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final point in forecast.points) ...[
                  _pointCard(context, point),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context, CashflowForecast forecast) {
    final scheme = Theme.of(context).colorScheme;
    final positive = forecast.isPositive;
    return Card(
      key: const ValueKey<String>('cashflow-forecast-status'),
      color: positive ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: positive ? scheme.primary : scheme.error,
              foregroundColor: positive ? scheme.onPrimary : scheme.onError,
              child: Icon(positive ? Icons.savings_outlined : Icons.warning_amber_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    positive ? 'السيولة المتوقعة موجبة' : 'في ضغط سيولة متوقع',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: positive ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    positive
                        ? 'بالبيانات الحالية، النموذج لا يرى عجزًا متوقعًا في الشهور المعروضة.'
                        : 'بالبيانات الحالية، النموذج يرى عجزًا متوقعًا ويستحق مراجعة الأرقام قبل أي التزام جديد.',
                    style: TextStyle(
                      color: positive ? scheme.onPrimaryContainer : scheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointCard(BuildContext context, CashflowForecastPoint point) {
    final scheme = Theme.of(context).colorScheme;
    final positive = point.projectedFreeCashMinorUnits >= 0;
    return Card(
      key: ValueKey<String>('cashflow-point-${point.periodLabel}'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.periodLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Icon(
                  positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: positive ? scheme.primary : scheme.error,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _metric('الدخل', point.incomeMinorUnits),
            _metric('الالتزامات', point.obligationsMinorUnits),
            _metric('الإنفاق التقديري', point.discretionaryExpenseEstimateMinorUnits),
            const Divider(height: 20),
            _metric('السيولة المتوقعة المتاحة', point.projectedFreeCashMinorUnits, emphasis: true),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, int minorUnits, {bool emphasis = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: emphasis ? FontWeight.w900 : FontWeight.w700),
            ),
          ),
          Text(
            _money(minorUnits),
            style: TextStyle(fontWeight: emphasis ? FontWeight.w900 : FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _money(int minorUnits) {
    final metadata = CurrencyRegistry.get(widget.currencyCode.trim().toUpperCase());
    final absolute = minorUnits.abs();
    final whole = absolute ~/ metadata.scale;
    final fraction = metadata.exponent == 0
        ? ''
        : '.${(absolute % metadata.scale).toString().padLeft(metadata.exponent, '0')}';
    return '${minorUnits < 0 ? '-' : ''}${_group(whole)}$fraction ${metadata.code}';
  }

  String _group(int value) {
    final text = value.toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return parts.join(',');
  }
}
