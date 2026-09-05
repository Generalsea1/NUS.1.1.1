import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/finance/data/local_debt_repository.dart';
import 'package:nus/features/finance/data/local_debt_settlement_repository.dart';
import 'package:nus/features/finance/domain/debt.dart';
import 'package:nus/features/finance/domain/debt_settlement.dart';

void main() {
  test('LocalDebtRepository isolates malformed records and preserves ordering', () async {
    SharedPreferences.setMockInitialValues({
      LocalDebtRepository.storageKey: '[{"id":"bad"},{"id":"d2","title":"B","direction":"owedByUser","principalMinorUnits":200,"currencyCode":"EGP","isArchived":false},{"id":"d1","title":"A","direction":"owedToUser","principalMinorUnits":100,"currencyCode":"EGP","isArchived":false}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalDebtRepository(preferences);

    final debts = await repository.list();

    expect(debts.map((debt) => debt.id), ['d1', 'd2']);
  });

  test('LocalDebtRepository uses archive semantics for delete', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalDebtRepository(preferences);
    final debt = Debt(
      id: 'd1',
      title: 'Debt',
      direction: DebtDirection.owedByUser,
      principalMinorUnits: 1000,
      currencyCode: 'EGP',
    );

    await repository.save(debt);
    await repository.deleteById('d1');

    expect((await repository.getById('d1'))!.isArchived, isTrue);
  });

  test('LocalDebtSettlementRepository isolates malformed records and orders by time', () async {
    SharedPreferences.setMockInitialValues({
      LocalDebtSettlementRepository.storageKey: '[{"id":"bad"},{"id":"s2","debtId":"d1","amountMinorUnits":200,"currencyCode":"EGP","settledAt":"2026-09-02T00:00:00.000Z"},{"id":"s1","debtId":"d1","amountMinorUnits":100,"currencyCode":"EGP","settledAt":"2026-09-01T00:00:00.000Z"}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalDebtSettlementRepository(preferences);

    final settlements = await repository.list();

    expect(settlements.map((settlement) => settlement.id), ['s1', 's2']);
  });

  test('root corruption fails closed on write', () async {
    SharedPreferences.setMockInitialValues({
      LocalDebtSettlementRepository.storageKey: '{"not":"a list"}',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalDebtSettlementRepository(preferences);
    final settlement = DebtSettlement(
      id: 's1',
      debtId: 'd1',
      amountMinorUnits: 100,
      currencyCode: 'EGP',
      settledAt: DateTime.utc(2026, 9, 1),
    );

    expect(
      () => repository.save(settlement),
      throwsA(isA<StateError>()),
    );
  });
}
