import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal shopping item domain model.
class ShoppingItem implements DomainEntity {
  const ShoppingItem({
    required this.id,
    required this.name,
    this.quantity,
    this.isCompleted = false,
  });

  @override
  final String id;
  final String name;
  final String? quantity;
  final bool isCompleted;
}

/// Repository port for shopping items.
abstract interface class ShoppingRepository
    implements DomainRepository<ShoppingItem> {}
