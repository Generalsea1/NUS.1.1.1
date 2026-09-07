import '../../expenses/application/expense_management_service.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_category.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../income/application/income_source_service.dart';
import 'financial_engine.dart';

enum HouseholdDataState { sufficient, insufficient }

class HouseholdMonthlyValue {
  const HouseholdMonthlyValue({
    required this.year,
    required this.month,
    required this.valueMinorUnits,
  });

  final int year;
  final int month;
  final int valueMinorUnits;

  String get periodLabel => '${month.toString().padLeft(2, '0')}/$year';
}

class HouseholdInsight {
  const HouseholdInsight({
    required this.type,
    required this.title,
    required this.explanation,
    required this.periodLabel,
    required this.currencyCode,
    required this.dataState,
    this.categoryCode,
    this.valueMinorUnits,
    this.comparisonValueMinorUnits,
    this.periodValues = const [],
  });

  final String type;
  final String title;
  final String explanation;
  final String periodLabel;
  final String currencyCode;
  final HouseholdDataState dataState;
  final String? categoryCode;
  final int? valueMinorUnits;
  final int? comparisonValueMinorUnits;
  final List<HouseholdMonthlyValue> periodValues;
}

class HouseholdIntelligenceSnapshot {
  const HouseholdIntelligenceSnapshot({
    required this.insights,
    required this.currencyCode,
    required this.periods,
  });

  final List<HouseholdInsight> insights;
  final String currencyCode;
  final List<HouseholdMonthlyValue> periods;

  bool get hasSufficientData => insights.any(
        (insight) => insight.dataState == HouseholdDataState.sufficient,
      );
}

class HouseholdIntelligenceService {
  HouseholdIntelligenceService({
    required FinancialEngine financialEngine,
    required ExpenseManagementService? expenseService,
    required IncomeSourceService incomeService,
  })  : _financialEngine = financialEngine,
        _expenseService = expenseService ??
            (throw ArgumentError('ExpenseManagementService is required.')),
        _incomeService = incomeService;

  final FinancialEngine _financialEngine;
  final ExpenseManagementService _expenseService;
  final IncomeSourceService _incomeService;

  Future<HouseholdIntelligenceSnapshot> analyze({
    required String userId,
    required int year,
    required int month,
    required String currencyCode,
    int historyMonths = 6,
  }) async {
    if (historyMonths < 1 || historyMonths > 12) {
      throw ArgumentError.value(
        historyMonths,
        'historyMonths',
        'History must contain between 1 and 12 months.',
      );
    }
    final currency = currencyCode.trim().toUpperCase();
    CurrencyRegistry.get(currency);

    final requestedPeriods = _buildPeriods(year, month, historyMonths);
    final snapshots = <FinancialSnapshot>[];
    final actualByPeriod = <String, Map<String, int>>{};

    for (final period in requestedPeriods) {
      snapshots.add(
        await _financialEngine.calculate(
          userId: userId,
          year: period.year,
          month: period.month,
          currencyCode: currency,
        ),
      );
      actualByPeriod[period.periodLabel] =
          await _expenseService.monthlyActualByCategory(
        year: period.year,
        month: period.month,
        currencyCode: currency,
      );
    }

    final allExpenses = await _expenseService.listExpenses();
    final currencyExpenses = allExpenses
        .where((expense) => expense.amount.currencyCode == currency)
        .toList(growable: false);
    final monthsWithActualData = <String>{
      for (final expense in currencyExpenses)
        if (_containsPeriod(requestedPeriods, expense))
          '${expense.date.month.toString().padLeft(2, '0')}/${expense.date.year}',
    };

    final current = snapshots.last;
    final currentKey = '${month.toString().padLeft(2, '0')}/$year';
    final currentCategories = actualByPeriod[currentKey] ?? const <String, int>{};
    final recurringDefinitions = await _expenseService.listRecurring();
    final hasCurrentRecurring = recurringDefinitions.any(
      (definition) =>
          definition.amount.currencyCode == currency &&
          definition.appliesToMonth(year, month),
    );
    final insights = <HouseholdInsight>[];

    if (currentCategories.isEmpty) {
      insights.add(
        HouseholdInsight(
          type: 'highest_category',
          title: 'أعلى بنود الإنفاق',
          explanation: 'مفيش مصروفات فعلية مسجلة بالعملة المختارة في الشهر ده، فمينفعش نحدد أعلى بند.',
          periodLabel: currentKey,
          currencyCode: currency,
          dataState: HouseholdDataState.insufficient,
        ),
      );
    } else {
      final highest = currentCategories.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );
      insights.add(
        HouseholdInsight(
          type: 'highest_category',
          title: 'أعلى بنود الإنفاق',
          explanation: 'أعلى فئة إنفاق فعلية مسجلة في الشهر المحدد هي ${ExpenseCategories.labelsAr[highest.key] ?? highest.key}.',
          periodLabel: currentKey,
          categoryCode: highest.key,
          currencyCode: currency,
          dataState: HouseholdDataState.sufficient,
          valueMinorUnits: highest.value,
        ),
      );
    }

    final periodValues = <HouseholdMonthlyValue>[
      for (var i = 0; i < requestedPeriods.length; i++)
        HouseholdMonthlyValue(
          year: requestedPeriods[i].year,
          month: requestedPeriods[i].month,
          valueMinorUnits: snapshots[i].actualExpensesMinorUnits,
        ),
    ];
    final availableTotals = periodValues
        .where((value) => monthsWithActualData.contains(value.periodLabel))
        .toList(growable: false);

    if (availableTotals.length < 3) {
      insights.add(
        HouseholdInsight(
          type: 'monthly_trend',
          title: 'اتجاه المصروفات',
          explanation: 'التاريخ المتاح أقل من 3 أشهر فيها مصروفات فعلية، لذلك الاتجاه الشهري غير كافي للحكم.',
          periodLabel: '${requestedPeriods.first.periodLabel} - ${requestedPeriods.last.periodLabel}',
          currencyCode: currency,
          dataState: HouseholdDataState.insufficient,
          periodValues: periodValues,
        ),
      );
    } else {
      final direction = _trendDirection(availableTotals.map((v) => v.valueMinorUnits).toList());
      final label = direction == 1
          ? 'المصروفات بتزيد تدريجيًا عبر الأشهر المتاحة.'
          : direction == -1
              ? 'المصروفات بتقل تدريجيًا عبر الأشهر المتاحة.'
              : 'المصروفات مش ماشية في اتجاه واحد ثابت عبر الأشهر المتاحة.';
      insights.add(
        HouseholdInsight(
          type: 'monthly_trend',
          title: 'اتجاه المصروفات',
          explanation: label,
          periodLabel: '${requestedPeriods.first.periodLabel} - ${requestedPeriods.last.periodLabel}',
          currencyCode: currency,
          dataState: HouseholdDataState.sufficient,
          valueMinorUnits: availableTotals.first.valueMinorUnits,
          comparisonValueMinorUnits: availableTotals.last.valueMinorUnits,
          periodValues: periodValues,
        ),
      );
    }

    insights.add(
      HouseholdInsight(
        type: 'recurring_vs_actual',
        title: 'المصروفات المتكررة',
        explanation: hasCurrentRecurring
            ? 'المقارنة بتفصل بين المصروفات الفعلية وبين المتكرر المتوقع؛ المتكرر المتوقع مش بيتعامل كمصروف فعلي.'
            : 'مفيش تعريفات متكررة مفعّلة بالعملة المختارة في الشهر ده، لذلك مفيش حكم آمن على عبء المتكرر.',
        periodLabel: currentKey,
        currencyCode: currency,
        dataState: hasCurrentRecurring
            ? HouseholdDataState.sufficient
            : HouseholdDataState.insufficient,
        valueMinorUnits: current.actualExpensesMinorUnits,
        comparisonValueMinorUnits: current.expectedRecurringExpensesMinorUnits,
      ),
    );

    final incomeSources = await _incomeService.list(userId);
    final enabledIncomeSources = incomeSources
        .where((source) => source.enabled && source.currencyCode == currency)
        .toList(growable: false);
    insights.add(
      HouseholdInsight(
        type: 'income_stability',
        title: 'استقرار الدخل',
        explanation: enabledIncomeSources.isEmpty
            ? 'مفيش مصدر دخل مسجل ومفعّل بالعملة المختارة؛ مينفعش نستنتج استقرار الدخل.'
            : 'فيه مصادر دخل مسجلة، لكن النظام الحالي ماعندوش سجل تحصيل تاريخي شهري يسمح بقياس استقرار الدخل بدون تخمين.',
        periodLabel: currentKey,
        currencyCode: currency,
        dataState: HouseholdDataState.insufficient,
      ),
    );

    final incomeMinor = current.monthlyIncomeMinorUnits;
    final obligationMinor = current.monthlyObligationsMinorUnits;
    insights.add(
      HouseholdInsight(
        type: 'obligation_burden',
        title: 'ضغط الالتزامات',
        explanation: incomeMinor == 0
            ? 'الالتزامات موجودة لكن مفيش دخل شهري موثوق بالعملة المختارة لقياس الضغط عليه.'
            : 'قارننا الالتزامات بالدخل فقط؛ الالتزامات لا تُعتبر مصروفات فعلية، ومفيش خصم مزدوج.',
        periodLabel: currentKey,
        currencyCode: currency,
        dataState: incomeMinor == 0
            ? HouseholdDataState.insufficient
            : HouseholdDataState.sufficient,
        valueMinorUnits: obligationMinor,
        comparisonValueMinorUnits: incomeMinor,
      ),
    );

    if (availableTotals.length >= 3) {
      final total = availableTotals.fold<int>(0, (sum, value) => sum + value.valueMinorUnits);
      final average = total ~/ availableTotals.length;
      final unusual = availableTotals
          .where((value) =>
              value.valueMinorUnits * 100 >= average * 120 ||
              value.valueMinorUnits * 100 <= average * 80)
          .toList(growable: false);
      insights.add(
        HouseholdInsight(
          type: 'unusual_months',
          title: 'مقارنة الأشهر',
          explanation: unusual.isEmpty
              ? 'مفيش شهر تعدّى أو نزل عن متوسط الفترة بأكثر من 20% حسب البيانات المتاحة.'
              : 'الشهور التالية مختلفة عن متوسط الفترة بأكثر من 20% حسب المصروفات الفعلية المسجلة.',
          periodLabel: '${requestedPeriods.first.periodLabel} - ${requestedPeriods.last.periodLabel}',
          currencyCode: currency,
          dataState: HouseholdDataState.sufficient,
          valueMinorUnits: average,
          periodValues: unusual,
        ),
      );
    } else {
      insights.add(
        HouseholdInsight(
          type: 'unusual_months',
          title: 'مقارنة الأشهر',
          explanation: 'محتاجين 3 أشهر أو أكثر فيها بيانات مصروفات فعلية قبل ما نحكم على شهر مرتفع أو منخفض بشكل غير معتاد.',
          periodLabel: '${requestedPeriods.first.periodLabel} - ${requestedPeriods.last.periodLabel}',
          currencyCode: currency,
          dataState: HouseholdDataState.insufficient,
          periodValues: periodValues,
        ),
      );
    }

    final categories = <String>{
      for (final byCategory in actualByPeriod.values) ...byCategory.keys,
    };
    final categoryChanges = <HouseholdInsight>[];
    for (final category in categories.toList()..sort()) {
      final values = <HouseholdMonthlyValue>[];
      for (final period in requestedPeriods) {
        final key = period.periodLabel;
        final map = actualByPeriod[key] ?? const <String, int>{};
        if (monthsWithActualData.contains(key) || map.containsKey(category)) {
          values.add(
            HouseholdMonthlyValue(
              year: period.year,
              month: period.month,
              valueMinorUnits: map[category] ?? 0,
            ),
          );
        }
      }
      if (values.length < 3) continue;
      final direction = _trendDirection(values.map((v) => v.valueMinorUnits).toList());
      if (direction == 0) continue;
      categoryChanges.add(
        HouseholdInsight(
          type: direction == 1 ? 'category_increasing' : 'category_decreasing',
          title: direction == 1 ? 'فئة إنفاق بتزيد' : 'فئة إنفاق بتقل',
          explanation:
              'البيانات المسجلة بتُظهر ${direction == 1 ? 'زيادة' : 'انخفاض'} منتظمة في ${ExpenseCategories.labelsAr[category] ?? category} عبر الأشهر المتاحة.',
          periodLabel: '${values.first.periodLabel} - ${values.last.periodLabel}',
          currencyCode: currency,
          dataState: HouseholdDataState.sufficient,
          categoryCode: category,
          valueMinorUnits: values.first.valueMinorUnits,
          comparisonValueMinorUnits: values.last.valueMinorUnits,
          periodValues: values,
        ),
      );
    }
    categoryChanges.sort((a, b) {
      final aDelta = (a.comparisonValueMinorUnits ?? 0) - (a.valueMinorUnits ?? 0);
      final bDelta = (b.comparisonValueMinorUnits ?? 0) - (b.valueMinorUnits ?? 0);
      return bDelta.abs().compareTo(aDelta.abs());
    });
    insights.addAll(categoryChanges.take(4));

    return HouseholdIntelligenceSnapshot(
      insights: List.unmodifiable(insights),
      currencyCode: currency,
      periods: List.unmodifiable(periodValues),
    );
  }

  List<_Period> _buildPeriods(int year, int month, int count) {
    final result = <_Period>[];
    for (var offset = count - 1; offset >= 0; offset--) {
      final date = DateTime(year, month - offset, 1);
      result.add(_Period(year: date.year, month: date.month));
    }
    return result;
  }

  bool _containsPeriod(List<_Period> periods, Expense expense) => periods.any(
        (period) => period.year == expense.date.year && period.month == expense.date.month,
      );

  int _trendDirection(List<int> values) {
    if (values.length < 2) return 0;
    var increasing = true;
    var decreasing = true;
    for (var i = 1; i < values.length; i++) {
      increasing = increasing && values[i] > values[i - 1];
      decreasing = decreasing && values[i] < values[i - 1];
    }
    if (increasing) return 1;
    if (decreasing) return -1;
    return 0;
  }
}

class _Period {
  const _Period({required this.year, required this.month});

  final int year;
  final int month;

  String get periodLabel => '${month.toString().padLeft(2, '0')}/$year';
}
