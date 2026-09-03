import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal expense domain model.
class Expense implements DomainEntity {
  const Expense({
    required this.id,
    required this.amount,
    required this.currencyCode,
    required this.occurredAt,
    this.category,
    this.note,
  });

  @override
  final String id;
  final num amount;
  final String currencyCode;
  final DateTime occurredAt;
  final String? category;
  final String? note;
}

/// Repository port for expenses.
abstract interface class ExpenseRepository
    implements DomainRepository<Expense> {}
