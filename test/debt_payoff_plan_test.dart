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

  test('schedule never exceeds supported thirty-year horizon', () {
    final plan = DebtPayoffPlan(
      id: 'd1',
      userId: 'u1',
      title: 'دين',
      currencyCode: 'EGP',
      totalBalanceMinorUnits: 3600,
      monthlyPaymentMinorUnits: 1,
      firstDueDate: DateTime(2026, 10, 5),
    );

    expect(plan.schedule.length, 360);
    expect(plan.schedule.last.remainingMinorUnits, 0);
  });
}
