import 'package:flutter/material.dart';

import '../../expenses/application/expense_management_service.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_engine.dart';
import '../../income/application/income_source_service.dart';
import '../../income/data/supabase_income_source_repository.dart';
import '../../onboarding/domain/household_profile.dart';
import '../../obligations/application/obligation_service.dart';
import '../../obligations/data/supabase_obligation_repository.dart';
import 'ask_nus_page.dart';

class NusAiCommandPage extends StatefulWidget {
  const NusAiCommandPage({
    super.key,
    required this.profile,
    required this.expenseManagementService,
  });

  final HouseholdProfile profile;
  final ExpenseManagementService expenseManagementService;

  @override
  State<NusAiCommandPage> createState() => _NusAiCommandPageState();
}

class _NusAiCommandPageState extends State<NusAiCommandPage> {
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

  FinancialAdvisorSnapshot? _snapshot;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final now = DateTime.now();
    try {
      final snapshot = await _engine.calculate(
        userId: widget.profile.userId,
        year: now.year,
        month: now.month,
        currencyCode: widget.profile.currencyCode,
      );
      Map<String, int> categories = const <String, int>{};
      try {
        categories = await widget.expenseManagementService.monthlyActualByCategory(
          year: now.year,
          month: now.month,
          currencyCode: widget.profile.currencyCode,
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _snapshot = FinancialAdvisorSnapshot(
          financial: snapshot,
          actualByCategory: Map<String, int>.unmodifiable(categories),
        );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _AiAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final snapshot = _snapshot;
    if (snapshot == null) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: const _AiAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.auto_awesome_rounded, size: 42, color: scheme.onErrorContainer),
                    const SizedBox(height: 10),
                    Text(
                      'المستشار الذكي لم يستطع قراءة البيانات المالية.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900, color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    Text(_error ?? 'خطأ غير معروف.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onErrorContainer)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _loadSnapshot,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة قراءة البيانات'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return AskNusPage(snapshot: snapshot);
  }
}

class _AiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AiAppBar();

  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('NUS الذكي', style: TextStyle(fontWeight: FontWeight.w900)),
      );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
