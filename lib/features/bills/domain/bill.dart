import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal bill domain model.
class Bill implements DomainEntity {
  const Bill({
    required this.id,
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.dueAt,
    this.isPaid = false,
  });

  @override
  final String id;
  final String title;
  final num amount;
  final String currencyCode;
  final DateTime dueAt;
  final bool isPaid;
}

/// Repository port for bills.
abstract interface class BillRepository implements DomainRepository<Bill> {}
