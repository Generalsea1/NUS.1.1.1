import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/domain/debt.dart';
import 'package:nus/features/finance/domain/debt_settlement.dart';

void main() {
  group('Debt', () {
    final dueAt = DateTime.utc(2026, 9, 30, 12);

    test('normalizes identity, title, currency and preserves core state', () {
      final debt = Debt(
        id: ' debt-1 ',
        title: '  Car repair  ',
        direction: DebtDirection.owedByUser,
        principalMinorUnits: 100000,
        currencyCode: 'egp',
        counterparty: ' Ahmed ',
        dueAt: dueAt,
      );

      expect(debt.id, 'debt-1');
      expect(debt.title, 'Car repair');
      expect(debt.currencyCode, 'EGP');
      expect(debt.counterparty, 'Ahmed');
      expect(debt.principalMinorUnits, 100000);
      expect(debt.isArchived, isFalse);
    });

    test('rejects invalid identity, principal and currency', () {
      expect(
        () => Debt(
          id: ' ',
          title: 'Debt',
          direction: DebtDirection.owedToUser,
          principalMinorUnits: 100,
          currencyCode: 'EGP',
        ),
        throwsArgumentError,
      );
      expect(
        () => Debt(
          id: 'd1',
          title: 'Debt',
          direction: DebtDirection.owedToUser,
          principalMinorUnits: 0,
          currencyCode: 'EGP',
        ),
        throwsArgumentError,
      );
      expect(
        () => Debt(
          id: 'd1',
          title: 'Debt',
          direction: DebtDirection.owedToUser,
          principalMinorUnits: 100,
          currencyCode: 'EGP1',
        ),
        throwsArgumentError,
      );
    });

    test('round trips deterministically and preserves archive identity', () {
      final debt = Debt(
        id: 'd1',
        title: 'Debt',
        direction: DebtDirection.owedToUser,
        principalMinorUnits: 150000,
        currencyCode: 'EGP',
        dueAt: dueAt,
      );

      expect(Debt.fromJson(debt.toJson()), debt);
      expect(debt.archive().id, debt.id);
      expect(debt.archive().isArchived, isTrue);
    });

    test('supports nullable optional fields without fake defaults', () {
      final debt = Debt(
        id: 'd1',
        title: 'Debt',
        direction: DebtDirection.owedToUser,
        principalMinorUnits: 150000,
        currencyCode: 'EGP',
      );

      expect(debt.counterparty, isNull);
      expect(debt.dueAt, isNull);
      expect(Debt.fromJson(debt.toJson()), debt);
    });
  });

  group('DebtSettlement', () {
    test('rejects zero or negative settlement amounts', () {
      expect(
        () => DebtSettlement(
          id: 's1',
          debtId: 'd1',
          amountMinorUnits: 0,
          currencyCode: 'EGP',
          settledAt: DateTime.utc(2026, 9, 1),
        ),
        throwsArgumentError,
      );
    });

    test('round trips and preserves optional transaction reference', () {
      final settlement = DebtSettlement(
        id: 's1',
        debtId: 'd1',
        amountMinorUnits: 5000,
        currencyCode: 'egp',
        settledAt: DateTime.utc(2026, 9, 1),
        note: 'first payment',
        financialTransactionId: 'tx-1',
      );

      expect(DebtSettlement.fromJson(settlement.toJson()), settlement);
      expect(settlement.currencyCode, 'EGP');
    });
  });
}
