import '../domain/installment_plan.dart';

abstract interface class InstallmentPlanRepository {
  Future<List<InstallmentPlan>> list(String userId);
  Future<InstallmentPlan> create(InstallmentPlan plan);
  Future<InstallmentPlan> update(InstallmentPlan plan);
  Future<void> delete(String userId, String planId);
}
