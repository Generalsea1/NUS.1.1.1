import '../domain/installment_plan.dart';
import 'installment_plan_repository.dart';

class InstallmentPlanService {
  InstallmentPlanService({required InstallmentPlanRepository repository})
      : _repository = repository;

  final InstallmentPlanRepository _repository;

  Future<List<InstallmentPlan>> list(String userId) {
    _validateUserId(userId);
    return _repository.list(userId.trim());
  }

  Future<InstallmentPlan> create(InstallmentPlan plan) async {
    _validateUserId(plan.userId);
    final clean = InstallmentPlan(
      id: plan.id,
      userId: plan.userId.trim(),
      title: plan.title.trim(),
      currencyCode: plan.currencyCode.trim().toUpperCase(),
      totalMinorUnits: plan.totalMinorUnits,
      downPaymentMinorUnits: plan.downPaymentMinorUnits,
      numberOfInstallments: plan.numberOfInstallments,
      paidInstallments: plan.paidInstallments,
      firstDueDate: plan.firstDueDate,
    );
    return _repository.create(clean);
  }

  Future<InstallmentPlan> update(InstallmentPlan plan) {
    _validateUserId(plan.userId);
    if (plan.id.trim().isEmpty) {
      throw ArgumentError.value(plan.id, 'id', 'Installment plan ID is required.');
    }
    return _repository.update(plan);
  }

  Future<void> delete(String userId, String planId) {
    _validateUserId(userId);
    if (planId.trim().isEmpty) {
      throw ArgumentError.value(planId, 'planId', 'Installment plan ID is required.');
    }
    return _repository.delete(userId.trim(), planId.trim());
  }

  static void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Authenticated user is required.');
    }
  }
}
