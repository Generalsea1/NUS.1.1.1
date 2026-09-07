import 'package:flutter/material.dart';

import '../../expenses/application/expense_lifecycle_service.dart';
import '../../expenses/presentation/household_expense_manager_page.dart';
import '../domain/household_profile.dart';

class FinancialDashboardPage extends StatelessWidget {
  const FinancialDashboardPage({
    super.key,
    required this.profile,
    this.expenseService,
    this.onOpenGeneralHome,
    this.onSignOut,
  });

  final HouseholdProfile profile;
  final ExpenseLifecycleService? expenseService;
  final VoidCallback? onOpenGeneralHome;
  final VoidCallback? onSignOut;

  String _format(int value) {
    final text = value.abs().toString();
    final parts = <String>[];
    for (var i = text.length; i > 0; i -= 3) {
      final start = i > 3 ? i - 3 : 0;
      parts.insert(0, text.substring(start, i));
    }
    return '${value < 0 ? '-' : ''}${parts.join(',')}';
  }

  String _money(int value) => '${_format(value)} ${profile.currencyCode}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = profile.remainingAfterObligations;
    final remainingPositive = remaining >= 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالتي المالية', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (onSignOut != null)
            IconButton(
              tooltip: 'تسجيل الخروج',
              onPressed: onSignOut,
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
            Text('${profile.householdSize} أفراد · ${profile.adults} بالغين · ${profile.children} أطفال · ${profile.currencyCode}'),
            const SizedBox(height: 18),
            _metricCard(
              context,
              title: 'الدخل الشهري',
              value: _money(profile.monthlyIncome),
              icon: Icons.account_balance_wallet_rounded,
            ),
            const SizedBox(height: 12),
            _metricCard(
              context,
              title: 'الالتزامات المتكررة الأولية',
              value: _money(profile.recurringObligations),
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: remainingPositive
                          ? scheme.primaryContainer
                          : scheme.errorContainer,
                      foregroundColor: remainingPositive
                          ? scheme.onPrimaryContainer
                          : scheme.onErrorContainer,
                      child: Icon(remainingPositive
                          ? Icons.savings_outlined
                          : Icons.warning_amber_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المتبقي بعد الالتزامات', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(
                            _money(remaining),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: remainingPositive ? scheme.primary : scheme.error,
                                ),
                          ),
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
                    Text('الدولة: ${profile.countryCode}'),
                    if (profile.region != null && profile.region!.isNotEmpty) Text('المنطقة: ${profile.region}'),
                    Text('السكن: ${_housingLabel(profile.housingType)}'),
                    Text('تكرار الدخل: ${_incomeFrequencyLabel(profile.incomeFrequency)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (expenseService != null)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HouseholdExpenseManagerPage(
                      service: expenseService!,
                      isArabic: true,
                    ),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('إدارة مصروفات البيت'),
              ),
            if (onOpenGeneralHome != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onOpenGeneralHome,
                icon: const Icon(Icons.apps_rounded),
                label: const Text('فتح باقي أدوات NUS'),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'الأرقام دي مبنية على بياناتك المحفوظة فقط. NUS لم يضع أي قيمة افتراضية مكان بياناتك.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              child: Icon(icon),
            ),
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
