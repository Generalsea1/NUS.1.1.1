import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/application/income_source_validator.dart';
import 'package:nus/features/income/domain/income_source.dart';
import 'package:nus/features/income/presentation/income_management_page.dart';
import 'package:nus/features/obligations/application/obligation_repository.dart';
import 'package:nus/features/obligations/application/obligation_service.dart';
import 'package:nus/features/obligations/domain/obligation.dart';
import 'package:nus/features/onboarding/domain/household_profile.dart';
import 'package:nus/features/onboarding/presentation/financial_dashboard_page.dart';

IncomeSource _source({
  String? id = 'income-1',
  String userId = 'u1',
  String name = 'مرتب',
  String sourceType = 'salary',
  int amount = 10000,
  String currencyCode = 'EGP',
  String frequency = 'monthly',
  bool enabled = true,
}) => IncomeSource(
      id: id,
      userId: userId,
      name: name,
      sourceType: sourceType,
      amount: amount,
      currencyCode: currencyCode,
      frequency: frequency,
      enabled: enabled,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

Obligation _dashboardObligation({int amount = 3000}) => Obligation(
      id: 'dashboard-obligation',
      userId: 'u1',
      name: 'التزام اختبار',
      type: 'rent',
      amount: amount,
      currencyCode: 'EGP',
      frequency: 'monthly',
      enabled: true,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

class FakeIncomeSourceRepository implements IncomeSourceRepository {
  final Map<String, IncomeSource> store = <String, IncomeSource>{};
  Object? listFailure;
  Object? createFailure;
  Object? updateFailure;
  Object? deleteFailure;
  Object? toggleFailure;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int toggleCalls = 0;
  int _nextId = 1;

  @override
  Future<List<IncomeSource>> list(String userId) async {
    if (listFailure != null) throw listFailure!;
    return store.values.where((source) => source.userId == userId).toList(growable: false);
  }

  @override
  Future<IncomeSource> create(IncomeSource source) async {
    createCalls++;
    if (createFailure != null) throw createFailure!;
    final saved = IncomeSource(
      id: source.id ?? 'income-${_nextId++}',
      userId: source.userId,
      name: source.name,
      sourceType: source.sourceType,
      amount: source.amount,
      currencyCode: source.currencyCode,
      frequency: source.frequency,
      enabled: source.enabled,
      createdAt: source.createdAt,
      updatedAt: source.updatedAt,
    );
    store[saved.id!] = saved;
    return saved;
  }

  @override
  Future<IncomeSource> update(IncomeSource source) async {
    updateCalls++;
    if (updateFailure != null) throw updateFailure!;
    final id = source.id;
    if (id == null || !store.containsKey(id)) throw StateError('missing');
    store[id] = source;
    return source;
  }

  @override
  Future<void> delete(String userId, String sourceId) async {
    deleteCalls++;
    if (deleteFailure != null) throw deleteFailure!;
    store.removeWhere((id, source) => id == sourceId && source.userId == userId);
  }

  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async {
    toggleCalls++;
    if (toggleFailure != null) throw toggleFailure!;
    final source = store[sourceId];
    if (source == null || source.userId != userId) throw StateError('missing');
    final updated = source.copyWith(enabled: enabled);
    store[sourceId] = updated;
    return updated;
  }
}

class _DashboardObligationRepository implements ObligationRepository {
  const _DashboardObligationRepository();

  @override
  Future<List<Obligation>> list(String userId) async =>
      <Obligation>[_dashboardObligation()];

  @override
  Future<Obligation> create(Obligation obligation) async => obligation;

  @override
  Future<Obligation> update(Obligation obligation) async => obligation;

  @override
  Future<void> delete(String userId, String obligationId) async {}

  @override
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) async =>
      _dashboardObligation().copyWith(enabled: enabled);
}

Widget _app(Widget child) => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );

final _profile = HouseholdProfile(
  userId: 'u1',
  countryCode: 'EG',
  region: 'Cairo',
  currencyCode: 'EGP',
  householdSize: 3,
  adults: 2,
  children: 1,
  housingType: 'rent',
  incomeFrequency: 'monthly',
  monthlyIncome: 10000,
  recurringObligations: 3000,
);

void main() {
  test('monthly normalization is exact', () {
    expect(IncomeNormalization.monthly(10000, 'monthly'), 10000);
  });

  test('weekly normalization uses 52 weeks per year and half-up rounding', () {
    expect(IncomeNormalization.monthly(1000, 'weekly'), 4333);
  });

  test('quarterly and yearly normalization are deterministic', () {
    expect(IncomeNormalization.monthly(30000, 'quarterly'), 10000);
    expect(IncomeNormalization.monthly(120000, 'yearly'), 10000);
    expect(IncomeNormalization.monthly(20000, 'biweekly'), 43333);
  });

  test('unsupported frequency is rejected by normalization and validation', () {
    expect(() => IncomeNormalization.monthly(1000, 'irregular'), throwsArgumentError);
    final source = _source(frequency: 'irregular');
    expect(const IncomeSourceValidator().validate(source), 'اختار تكرار دخل صحيح.');
  });

  test('invalid amount and currency are rejected', () {
    expect(() => _source(amount: 0), throwsArgumentError);
    final invalidCurrency = _source(currencyCode: 'ZZZ');
    expect(const IncomeSourceValidator().validate(invalidCurrency), contains('مدعومة'));
  });

  test('disabled sources are excluded and enabled sources are summed', () {
    const service = IncomeSourceService(repository: _NoopRepository());
    final sources = <IncomeSource>[
      _source(id: 'salary', amount: 10000),
      _source(id: 'rent', name: 'إيجار', sourceType: 'rent', amount: 5000),
      _source(id: 'weekly', name: 'أسبوعي', amount: 1000, frequency: 'weekly', enabled: false),
    ];
    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 15000);
  });

  test('multiple sources normalize and sum correctly', () {
    const service = IncomeSourceService(repository: _NoopRepository());
    final sources = <IncomeSource>[
      _source(id: 'salary', amount: 10000),
      _source(id: 'quarterly', name: 'عمل حر', sourceType: 'freelance', amount: 4000, frequency: 'quarterly'),
    ];
    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 11333);
  });

  test('repository CRUD and failure propagation work through the boundary', () async {
    final repository = FakeIncomeSourceRepository();
    final source = _source();
    final created = await repository.create(source.copyWith());
    expect(created.id, 'income-1');
    expect((await repository.list('u1')).single.name, 'مرتب');

    final updated = created.copyWith(name: 'المرتب الأساسي', amount: 12000);
    await repository.update(updated);
    expect((await repository.list('u1')).single.amount, 12000);

    await repository.setEnabled('u1', 'income-1', false);
    expect((await repository.list('u1')).single.enabled, isFalse);

    await repository.delete('u1', 'income-1');
    expect(await repository.list('u1'), isEmpty);

    repository.createFailure = StateError('create');
    expect(repository.create(source), throwsStateError);
    repository.createFailure = null;
    repository.updateFailure = StateError('update');
    expect(repository.update(source.copyWith()), throwsStateError);
    repository.updateFailure = null;
    repository.toggleFailure = StateError('toggle');
    expect(repository.setEnabled('u1', 'income-1', true), throwsStateError);
    repository.deleteFailure = StateError('delete');
    expect(repository.delete('u1', 'income-1'), throwsStateError);
  });

  group('Income Management UI', () {
    testWidgets('existing sources are displayed with normalized total', (tester) async {
      final repository = FakeIncomeSourceRepository()
        ..store['salary'] = _source(id: 'salary', amount: 10000)
        ..store['freelance'] = _source(id: 'freelance', name: 'عمل حر', sourceType: 'freelance', amount: 4000, frequency: 'quarterly');
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('income-source-salary')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('income-source-freelance')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('income-total-monthly')), findsOneWidget);
      expect(find.text('11333 EGP'), findsOneWidget);
    });

    testWidgets('add source persists through repository and updates total', (tester) async {
      final repository = FakeIncomeSourceRepository()..store['salary'] = _source(id: 'salary');
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('income-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('income-name')), 'إيجار');
      await tester.enterText(find.byKey(const ValueKey<String>('income-amount')), '5000');
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(repository.store.values.any((source) => source.name == 'إيجار'), isTrue);
      expect(find.text('15000 EGP'), findsOneWidget);
    });

    testWidgets('edit source updates persisted value and total', (tester) async {
      final repository = FakeIncomeSourceRepository()..store['salary'] = _source(id: 'salary');
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('income-edit-salary')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('income-amount')), '12000');
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
      expect(repository.store['salary']!.amount, 12000);
      expect(find.text('12000 EGP'), findsOneWidget);
    });

    testWidgets('toggle excludes disabled source from total', (tester) async {
      final repository = FakeIncomeSourceRepository()
        ..store['salary'] = _source(id: 'salary', amount: 10000)
        ..store['rent'] = _source(id: 'rent', name: 'إيجار', sourceType: 'rent', amount: 5000);
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('income-toggle-rent')));
      await tester.pumpAndSettle();
      expect(repository.toggleCalls, 1);
      expect(repository.store['rent']!.enabled, isFalse);
      expect(find.text('10000 EGP'), findsOneWidget);
    });

    testWidgets('normal source can be deleted and total updates', (tester) async {
      final repository = FakeIncomeSourceRepository()
        ..store['salary'] = _source(id: 'salary')
        ..store['rent'] = _source(id: 'rent', name: 'إيجار', sourceType: 'rent', amount: 5000);
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      final deleteButton = find.byKey(const ValueKey<String>('income-delete-rent'));
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('حذف مصدر الدخل؟'), findsOneWidget);
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(repository.deleteCalls, 1);
      expect(repository.store.containsKey('rent'), isFalse);
      expect(find.text('10000 EGP'), findsOneWidget);
    });

    testWidgets('legacy source remains protected from deletion', (tester) async {
      final repository = FakeIncomeSourceRepository()..store['legacy'] = _source(id: 'legacy', name: 'الدخل الأساسي من إعداد البيت', sourceType: 'legacy');
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('income-delete-legacy')), findsNothing);
      expect(find.byKey(const ValueKey<String>('income-edit-legacy')), findsOneWidget);
    });

    testWidgets('save failure keeps form data and retry succeeds', (tester) async {
      final repository = FakeIncomeSourceRepository()..createFailure = StateError('save');
      await tester.pumpWidget(_app(IncomeManagementPage(
        userId: 'u1',
        householdCurrencyCode: 'EGP',
        service: IncomeSourceService(repository: repository),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('income-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('income-name')), 'عمل حر');
      await tester.enterText(find.byKey(const ValueKey<String>('income-amount')), '4000');
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await tester.pump();
      expect(find.byKey(const ValueKey<String>('income-form-error')), findsOneWidget);
      expect(find.text('4000'), findsOneWidget);
      expect(find.text('عمل حر'), findsOneWidget);
      expect(repository.createCalls, 1);

      repository.createFailure = null;
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await tester.pumpAndSettle();
      expect(repository.createCalls, 2);
      expect(repository.store.values.any((source) => source.name == 'عمل حر'), isTrue);
    });

    testWidgets('reload keeps persisted sources', (tester) async {
      final repository = FakeIncomeSourceRepository()..store['salary'] = _source(id: 'salary', amount: 11000);
      final service = IncomeSourceService(repository: repository);
      await tester.pumpWidget(_app(IncomeManagementPage(userId: 'u1', householdCurrencyCode: 'EGP', service: service)));
      await tester.pumpAndSettle();
      expect(find.text('11000 EGP'), findsOneWidget);

      await tester.pumpWidget(_app(IncomeManagementPage(userId: 'u1', householdCurrencyCode: 'EGP', service: service)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('income-source-salary')), findsOneWidget);
      expect(find.text('11000 EGP'), findsOneWidget);
    });

    testWidgets('currency mismatch is rejected without repository write', (tester) async {
      final repository = FakeIncomeSourceRepository();
      await tester.pumpWidget(_app(IncomeManagementPage(userId: 'u1', householdCurrencyCode: 'EGP', service: IncomeSourceService(repository: repository))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('income-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey<String>('income-name')), 'دخل');
      await tester.enterText(find.byKey(const ValueKey<String>('income-amount')), '1000');
      await tester.enterText(find.byKey(const ValueKey<String>('income-currency')), 'USD');
      await tester.tap(find.byKey(const ValueKey<String>('income-save')));
      await tester.pump();
      expect(find.text('عملة مصدر الدخل لازم تطابق عملة البيت الحالية.'), findsOneWidget);
      expect(repository.createCalls, 0);
    });
  });

  testWidgets('dashboard uses normalized income sources and subtracts real obligations', (tester) async {
    final repository = FakeIncomeSourceRepository()
      ..store['salary'] = _source(id: 'salary', amount: 10000)
      ..store['freelance'] = _source(id: 'freelance', name: 'عمل حر', sourceType: 'freelance', amount: 4000, frequency: 'quarterly');
    await tester.pumpWidget(_app(FinancialDashboardPage(
      profile: _profile,
      incomeRepository: repository,
      obligationService: const ObligationService(repository: _DashboardObligationRepository()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('11,333 EGP'), findsOneWidget);
    expect(find.text('-?'), findsNothing);
    expect(find.text('8,333 EGP'), findsOneWidget);
    expect(find.text('إدارة مصادر الدخل'), findsOneWidget);
  });

  testWidgets('dashboard preserves Slice 1 monthly income when income source read fails', (tester) async {
    final repository = FakeIncomeSourceRepository()..listFailure = StateError('offline');
    await tester.pumpWidget(_app(FinancialDashboardPage(
      profile: _profile,
      incomeRepository: repository,
      obligationService: const ObligationService(repository: _DashboardObligationRepository()),
    )));
    await tester.pumpAndSettle();
    expect(find.text('10,000 EGP'), findsOneWidget);
    expect(find.text('3,000 EGP'), findsOneWidget);
    final remaining = find.text('7,000 EGP');
    await tester.scrollUntilVisible(remaining, 200.0, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(remaining, findsOneWidget);
    expect(find.textContaining('مصادر الدخل التفصيلية غير متاحة الآن'), findsOneWidget);
  });
}

class _NoopRepository implements IncomeSourceRepository {
  const _NoopRepository();
  @override
  Future<List<IncomeSource>> list(String userId) async => const <IncomeSource>[];
  @override
  Future<IncomeSource> create(IncomeSource source) async => source;
  @override
  Future<IncomeSource> update(IncomeSource source) async => source;
  @override
  Future<void> delete(String userId, String sourceId) async {}
  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async => sourceId == 'unused' ? throw StateError('unused') : _source(id: sourceId, enabled: enabled);
}
