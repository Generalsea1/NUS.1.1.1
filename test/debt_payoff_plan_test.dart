import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/domain/debt_payoff_plan.dart';

void main() {
  test('exact schedule closes the balance on the final payment', () {
    final plan = DebtPayoffPlan(
      id: 'd1',
      userId: 'u1',
      title: 'بطاقة ائتمان',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 1000,
      monthlyPaymentMinorUnits: 300,
      firstDueDate: DateTime(2026, 10, 5),
    );

    expect(plan.estimatedMonths, 4);
    expect(plan.schedule.length, 4);
    expect(plan.schedule.map((item) => item.paymentMinorUnits), [300, 300, 300, 100]);
    expect(plan.schedule.last.remainingMinorUnits, 0);
    expect(plan.schedule.map((item) => item.dueDate.month), [10, 11, 12, 1]);
  });

  test('extra payment reduces the payoff horizon', () {
    final plan = DebtPayoffPlan(
      id: 'd1',
      userId: 'u1',
      title: 'قرض',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 10000,
      monthlyPaymentMinorUnits: 2000,
      extraMonthlyPaymentMinorUnits: 500,
      firstDueDate: DateTime(2026, 10, 5),
    );

    expect(plan.effectiveMonthlyPaymentMinorUnits, 2500);
    expect(plan.estimatedMonths, 4);
  });

  test('invalid debt inputs are rejected', () {
    expect(
      () => DebtPayoffPlan(
        id: '',
        userId: 'u1',
        title: 'دين',
        currencyCode: 'EGP',
        totalBalanceMinorUnits: 1000,
        monthlyPaymentMinorUnits: 100,
        firstDueDate: DateTime(2026, 10, 5),
      ),
      throwsArgumentError,
    );
    expect(
      () => DebtPayoffPlan(
        id: 'd1',
        userId: 'u1',
        title: 'دين',
        currencyCode: 'EGP',
        totalBalanceMinorUnits: 1000,
        monthlyPaymentMinorUnits: 0,
        firstDueDate: DateTime(2026, 10, 5),
      ),
      throwsArgumentError,
    );
  });

  test('accepts exactly the thirty-year boundary and rejects anything longer', () {
    final boundary = DebtPayoffPlan(
      id: 'd-boundary',
      userId: 'u1',
      title: 'دين طويل',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 360,
      monthlyPaymentMinorUnits: 1,
      firstDueDate: DateTime(2026, 10, 5),
    );

    expect(boundary.estimatedMonths, DebtPayoffPlan.maxPayoffMonths);
    expect(boundary.schedule.length, DebtPayoffPlan.maxPayoffMonths);
    expect(boundary.schedule.last.remainingMinorUnits, 0);

    expect(
      () => DebtPayoffPlan(
        id: 'd-too-long',
        userId: 'u1',
        title: 'دين أطول من اللازم',
        currencyCode: 'EGP',
        totalBalanceMinorUnits: 361,
        monthlyPaymentMinorUnits: 1,
        firstDueDate: DateTime(2026, 10, 5),
      ),
      throwsArgumentError,
    );
  });

  test('month-end dates stay in the next month instead of overflowing it', () {
    final plan = DebtPayoffPlan(
      id: 'd-month-end',
      userId: 'u1',
      title: 'إيجار متأخر',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 300,
      monthlyPaymentMinorUnits: 100,
      firstDueDate: DateTime(2026, 1, 31),
    );

    expect(
      plan.schedule.map((item) => '${item.dueDate.year}-${item.dueDate.month}-${item.dueDate.day}').toList(),
      ['2026-1-31', '2026-2-28', '2026-3-28'],
    );

    final leapPlan = DebtPayoffPlan(
      id: 'd-leap-month-end',
      userId: 'u1',
      title: 'دفع يوم 29',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 300,
      monthlyPaymentMinorUnits: 100,
      firstDueDate: DateTime(2028, 1, 29),
    );

    expect(
      leapPlan.schedule.map((item) => '${item.dueDate.year}-${item.dueDate.month}-${item.dueDate.day}').toList(),
      ['2028-1-29', '2028-2-29', '2028-3-29'],
    );
  });
}
