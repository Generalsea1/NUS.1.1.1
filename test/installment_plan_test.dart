import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/finance/domain/installment_plan.dart';

void main() {
  test('splits a financed amount exactly across installments', () {
    final plan = InstallmentPlan(
      id: 'p1',
      userId: 'u1',
      title: 'Laptop',
      currencyCode: 'EGP',
      totalMinorUnits: 1001,
      downPaymentMinorUnits: 1,
      numberOfInstallments: 3,
      paidInstallments: 0,
      firstDueDate: DateTime(2026, 9, 15),
    );

    expect(plan.financedMinorUnits, 1000);
    expect(plan.installmentAmountMinorUnits(1), 334);
    expect(plan.installmentAmountMinorUnits(2), 333);
    expect(plan.installmentAmountMinorUnits(3), 333);
    expect(plan.dueDateFor(2), DateTime(2026, 10, 15));
  });

  test('calculates paid and remaining balances', () {
    final plan = InstallmentPlan(
      id: 'p1',
      userId: 'u1',
      title: 'Phone',
      currencyCode: 'EGP',
      totalMinorUnits: 120000,
      downPaymentMinorUnits: 20000,
      numberOfInstallments: 5,
      paidInstallments: 2,
      firstDueDate: DateTime(2026, 9, 20),
    );

    expect(plan.paidInstallmentsTotalMinorUnits, 40000);
    expect(plan.remainingInstallments, 3);
    expect(plan.remainingBalanceMinorUnits, 60000);
  });

  test('rejects invalid core values', () {
    expect(
      () => InstallmentPlan(
        id: '',
        userId: 'u1',
        title: 'Bad',
        currencyCode: 'EGP',
        totalMinorUnits: 100,
        downPaymentMinorUnits: 0,
        numberOfInstallments: 2,
        paidInstallments: 0,
        firstDueDate: DateTime(2026, 9, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => InstallmentPlan(
        id: 'p',
        userId: 'u1',
        title: 'Bad',
        currencyCode: 'EGP',
        totalMinorUnits: 100,
        downPaymentMinorUnits: 100,
        numberOfInstallments: 2,
        paidInstallments: 0,
        firstDueDate: DateTime(2026, 9, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => InstallmentPlan(
        id: 'p',
        userId: 'u1',
        title: 'Bad',
        currencyCode: 'EGP',
        totalMinorUnits: 100,
        downPaymentMinorUnits: 0,
        numberOfInstallments: 0,
        paidInstallments: 0,
        firstDueDate: DateTime(2026, 9, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects impossible installment access', () {
    final plan = InstallmentPlan(
      id: 'p1',
      userId: 'u1',
      title: 'Phone',
      currencyCode: 'EGP',
      totalMinorUnits: 1000,
      downPaymentMinorUnits: 0,
      numberOfInstallments: 4,
      paidInstallments: 0,
      firstDueDate: DateTime(2026, 9, 1),
    );

    expect(() => plan.installmentAmountMinorUnits(0), throwsA(isA<RangeError>()));
    expect(() => plan.dueDateFor(5), throwsA(isA<RangeError>()));
  });
}
