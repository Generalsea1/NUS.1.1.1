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

  test('round trips exact values through the persistence map', () {
    final plan = InstallmentPlan(
      id: 'p1',
      userId: 'u1',
      title: 'Phone',
      currencyCode: 'USD',
      totalMinorUnits: 100075,
      downPaymentMinorUnits: 75,
      numberOfInstallments: 2,
      paidInstallments: 1,
      firstDueDate: DateTime(2026, 9, 20),
    );

    final restored = InstallmentPlan.fromMap(plan.toMap());

    expect(restored.id, plan.id);
    expect(restored.userId, plan.userId);
    expect(restored.totalMinorUnits, plan.totalMinorUnits);
    expect(restored.downPaymentMinorUnits, plan.downPaymentMinorUnits);
    expect(restored.paidInstallments, plan.paidInstallments);
    expect(restored.firstDueDate, plan.firstDueDate);
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
    expect(
      () => InstallmentPlan(
        id: 'p',
        userId: 'u1',
        title: 'Too many',
        currencyCode: 'EGP',
        totalMinorUnits: 100,
        downPaymentMinorUnits: 0,
        numberOfInstallments: InstallmentPlan.maxInstallments + 1,
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

  test('month-end due dates clamp to the valid day in the next month', () {
    final plan = InstallmentPlan(
      id: 'month-end',
      userId: 'u1',
      title: 'Month end',
      currencyCode: 'EGP',
      totalMinorUnits: 300,
      downPaymentMinorUnits: 0,
      numberOfInstallments: 3,
      paidInstallments: 0,
      firstDueDate: DateTime(2026, 1, 31),
    );

    expect(plan.dueDateFor(1), DateTime(2026, 1, 31));
    expect(plan.dueDateFor(2), DateTime(2026, 2, 28));
    expect(plan.dueDateFor(3), DateTime(2026, 3, 28));
  });

  test('leap-year day 29 remains stable through February', () {
    final plan = InstallmentPlan(
      id: 'leap',
      userId: 'u1',
      title: 'Leap',
      currencyCode: 'EGP',
      totalMinorUnits: 200,
      downPaymentMinorUnits: 0,
      numberOfInstallments: 2,
      paidInstallments: 0,
      firstDueDate: DateTime(2028, 1, 29),
    );

    expect(plan.dueDateFor(2), DateTime(2028, 2, 29));
  });
}
