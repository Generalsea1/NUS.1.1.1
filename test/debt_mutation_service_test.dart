import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/debt_mutation_service.dart';
import 'package:nus/features/finance/domain/debt.dart';
import 'package:nus/features/finance/domain/debt_settlement.dart';

class FakeDebtRepository implements DebtRepository {
  final Map<String, Debt> items = {};

  @override
  Future<Debt?> getById(String id) async => items[id.trim()];

  @override
  Future<List<Debt>> list() async => items.values.toList(growable: false);

  @override
  Future<void> save(Debt entity) async => items[entity.id] = entity;

  @override
  Future<void> deleteById(String id) async => items.remove(id.trim());

  @override
  Future<void> archiveById(String id) async {
    final debt = items[id.trim()];
    if (debt != null) items[id.trim()] = debt.archive();
  }
}

class FakeDebtSettlementRepository implements DebtSettlementRepository {
  final Map<String, DebtSettlement> items = {};

  @override
  Future<DebtSettlement?> getById(String id) async => items[id.trim()];

  @override
  Future<List<DebtSettlement>> list() async =>
      items.values.toList(growable: false);

  @override
  Future<void> save(DebtSettlement entity) async => items[entity.id] = entity;

  @override
  Future<void> deleteById(String id) async => items.remove(id.trim());
}

void main() {
  late FakeDebtRepository debts;
  late FakeDebtSettlementRepository settlements;
  late DebtMutationService service;

  setUp(() {
    debts = FakeDebtRepository();
    settlements = FakeDebtSettlementRepository();
    service = DebtMutationService(
      debtRepository: debts,
      settlementRepository: settlements,
    );
  });

  Debt debt({
    String id = 'd1',
    int principal = 10000,
    int settled = 0,
    String currency = 'EGP',
    bool archived = false,
  }) => Debt(
        id: id,
        title: 'Repair loan',
        direction: DebtDirection.owedByUser,
        principalMinorUnits: principal,
        currencyCode: currency,
        settledMinorUnits: settled,
        isArchived: archived,
      );

  test('create rejects duplicate stable IDs', () async {
    await service.createDebt(debt());

    expect(
      () => service.createDebt(debt()),
      throwsA(isA<DebtDuplicateIdException>()),
    );
  });

  test('update requires an existing debt and preserves repository boundary',
      () async {
    expect(
      () => service.updateDebt(debt()),
      throwsA(isA<DebtNotFoundException>()),
    );

    await service.createDebt(debt());
    await service.updateDebt(
      debt(principal: 12000, settled: 1000),
    );

    expect(debts.items['d1']!.principalMinorUnits, 12000);
    expect(debts.items['d1']!.settledMinorUnits, 1000);
  });

  test('settlement validates currency, duplicate ID and outstanding amount',
      () async {
    await service.createDebt(debt());

    expect(
      () => service.settleDebt(
        settlementId: 's1',
        debtId: 'd1',
        amountMinorUnits: 1000,
        currencyCode: 'USD',
        settledAt: DateTime.utc(2026, 9, 1),
      ),
      throwsA(isA<DebtSettlementCurrencyMismatchException>()),
    );

    expect(
      () => service.settleDebt(
        settlementId: 's1',
        debtId: 'd1',
        amountMinorUnits: 10001,
        currencyCode: 'EGP',
        settledAt: DateTime.utc(2026, 9, 1),
      ),
      throwsA(isA<DebtSettlementExceedsOutstandingException>()),
    );

    await service.settleDebt(
      settlementId: 's1',
      debtId: 'd1',
      amountMinorUnits: 4000,
      currencyCode: 'EGP',
      settledAt: DateTime.utc(2026, 9, 1),
    );

    expect(debts.items['d1']!.settledMinorUnits, 4000);
    expect(debts.items['d1']!.outstandingMinorUnits, 6000);

    expect(
      () => service.settleDebt(
        settlementId: 's1',
        debtId: 'd1',
        amountMinorUnits: 100,
        currencyCode: 'EGP',
        settledAt: DateTime.utc(2026, 9, 2),
      ),
      throwsA(isA<DebtSettlementDuplicateIdException>()),
    );
  });

  test('full settlement closes debt and history remains separately queryable',
      () async {
    await service.createDebt(debt());

    await service.settleDebt(
      settlementId: 's1',
      debtId: 'd1',
      amountMinorUnits: 7000,
      currencyCode: 'EGP',
      settledAt: DateTime.utc(2026, 9, 1),
    );
    await service.settleDebt(
      settlementId: 's2',
      debtId: 'd1',
      amountMinorUnits: 3000,
      currencyCode: 'EGP',
      settledAt: DateTime.utc(2026, 9, 5),
    );

    expect(debts.items['d1']!.isSettled, isTrue);
    expect(await service.settlementsForDebt('d1'), hasLength(2));
  });

  test('archiving does not delete the debt identity', () async {
    await service.createDebt(debt());
    await service.archiveDebt('d1');

    expect(debts.items['d1']!.isArchived, isTrue);
  });
}
