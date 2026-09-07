import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/income/application/income_source_repository.dart';
import 'package:nus/features/income/application/income_source_service.dart';
import 'package:nus/features/income/domain/income_source.dart';

class _FakeIncomeSourceRepository implements IncomeSourceRepository {
  final Map<String, IncomeSource> store = <String, IncomeSource>{};
  int _nextId = 1;

  @override
  Future<List<IncomeSource>> list(String userId) async =>
      store.values.where((source) => source.userId == userId).toList(growable: false);

  @override
  Future<IncomeSource> create(IncomeSource source) async {
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
    store[source.id!] = source;
    return source;
  }

  @override
  Future<void> delete(String userId, String sourceId) async {
    store.removeWhere((id, source) => id == sourceId && source.userId == userId);
  }

  @override
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) async {
    final source = store[sourceId]!;
    final updated = source.copyWith(enabled: enabled);
    store[sourceId] = updated;
    return updated;
  }
}

IncomeSource _source({
  required String id,
  required String name,
  required String sourceType,
  required int amount,
  bool enabled = true,
}) => IncomeSource(
      id: id,
      userId: 'u1',
      name: name,
      sourceType: sourceType,
      amount: amount,
      currencyCode: 'EGP',
      frequency: 'monthly',
      enabled: enabled,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  test('legacy-only income remains the Slice 1 monthly income', () {
    const service = IncomeSourceService(repository: _FakeIncomeSourceRepository());
    final sources = <IncomeSource>[
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
      ),
    ];

    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 10000);
  });

  test('first real salary replaces the legacy compatibility representation for totals', () {
    const service = IncomeSourceService(repository: _FakeIncomeSourceRepository());
    final sources = <IncomeSource>[
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
      ),
      _source(
        id: 'salary',
        name: 'المرتب الأساسي',
        sourceType: 'salary',
        amount: 10000,
      ),
    ];

    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 10000);
  });

  test('legacy income does not double count when a real source exists and additional income is added', () {
    const service = IncomeSourceService(repository: _FakeIncomeSourceRepository());
    final sources = <IncomeSource>[
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
      ),
      _source(
        id: 'salary',
        name: 'المرتب الأساسي',
        sourceType: 'salary',
        amount: 10000,
      ),
      _source(
        id: 'rent',
        name: 'إيجار',
        sourceType: 'rent',
        amount: 3000,
      ),
    ];

    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 13000);
  });

  test('disabled real sources do not suppress an active legacy fallback', () {
    const service = IncomeSourceService(repository: _FakeIncomeSourceRepository());
    final sources = <IncomeSource>[
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
      ),
      _source(
        id: 'salary',
        name: 'المرتب الأساسي',
        sourceType: 'salary',
        amount: 10000,
        enabled: false,
      ),
    ];

    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 10000);
  });

  test('disabled legacy and disabled real sources both contribute zero', () {
    const service = IncomeSourceService(repository: _FakeIncomeSourceRepository());
    final sources = <IncomeSource>[
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
        enabled: false,
      ),
      _source(
        id: 'salary',
        name: 'المرتب الأساسي',
        sourceType: 'salary',
        amount: 10000,
        enabled: false,
      ),
    ];

    expect(service.totalMonthlyIncome(sources, currencyCode: 'EGP'), 0);
  });

  test('legacy transition behavior survives repository reload', () async {
    final repository = _FakeIncomeSourceRepository();
    final service = IncomeSourceService(repository: repository);
    await repository.create(
      _source(
        id: 'legacy',
        name: 'الدخل الأساسي من إعداد البيت',
        sourceType: 'legacy',
        amount: 10000,
      ),
    );
    await repository.create(
      _source(
        id: 'salary',
        name: 'المرتب الأساسي',
        sourceType: 'salary',
        amount: 10000,
      ),
    );

    final reloadedSources = await service.list('u1');
    expect(service.totalMonthlyIncome(reloadedSources, currencyCode: 'EGP'), 10000);
    expect(reloadedSources.where((source) => source.sourceType == 'legacy'), hasLength(1));
    expect(reloadedSources.where((source) => source.sourceType == 'salary'), hasLength(1));
  });
}
