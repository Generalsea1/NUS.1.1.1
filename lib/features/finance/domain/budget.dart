import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal budget domain model.
class Budget implements DomainEntity {
  const Budget({
    required this.id,
    required this.name,
    required this.amount,
    required this.currencyCode,
    required this.periodStart,
    required this.periodEnd,
  });

  @override
  final String id;
  final String name;
  final num amount;
  final String currencyCode;
  final DateTime periodStart;
  final DateTime periodEnd;
}

/// Repository port for budgets.
abstract interface class BudgetRepository
    implements DomainRepository<Budget> {}
