import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/finance/application/installment_plan_repository.dart';
import 'package:nus/features/finance/application/installment_plan_service.dart';
import 'package:nus/features/finance/domain/installment_plan.dart';

class _FakeInstallmentRepository implements InstallmentPlanRepository {
  final List<InstallmentPlan> plans = [];

  @override
  Future<List<InstallmentPlan>> list(String userId) async =>
      plans.where((plan) => plan.userId == userId).toList(growable: false);

  @override
  Future<InstallmentPlan> create(InstallmentPlan plan) async {
    plans.add(plan);
    return plan;
  }

  @override
  Future<InstallmentPlan> update(InstallmentPlan plan) async {
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index == -1) throw StateError('missing');
    plans[index] = plan;
    return plan;
  }

  @override
  Future<void> delete(String userId, String planId) async {
    plans.removeWhere((plan) => plan.userId == userId && plan.id == planId);
  }
}

void main() {
  test('creates and lists only the authenticated user plans through the service boundary', () async {
    final repository = _FakeInstallmentRepository();
    final service = InstallmentPlanService(repository: repository);
    final plan = InstallmentPlan(
      id: 'p1',
      userId: 'u1',
      title: 'Laptop',
      currencyCode: 'EGP',
      totalMinorUnits: 100000,
      downPaymentMinorUnits: 10000,
      numberOfInstallments: 5,
      paidInstallments: 0,
      firstDueDate: DateTime(2026, 9, 15),
    );

    await service.create(plan);
    await repository.create(
      InstallmentPlan(
        id: 'p2',
        userId: 'u2',
        title: 'Phone',
        currencyCode: 'EGP',
        totalMinorUnits: 50000,
        downPaymentMinorUnits: 5000,
        numberOfInstallments: 5,
        paidInstallments: 0,
        firstDueDate: DateTime(2026, 9, 15),
      ),
    );

    final listed = await service.list('u1');
    expect(listed, hasLength(1));
    expect(listed.single.id, 'p1');
  });

  test('rejects empty owner IDs before repository access', () {
    final service = InstallmentPlanService(repository: _FakeInstallmentRepository());
    expect(() => service.list(' '), throwsArgumentError);
    expect(
      () => service.delete('u1', ' '),
      throwsArgumentError,
    );
  });
}
