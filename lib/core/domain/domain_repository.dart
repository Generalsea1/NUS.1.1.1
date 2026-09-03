import 'domain_entity.dart';

/// Optional CRUD-shaped repository port for feature domains.
///
/// Feature-specific repositories may narrow or extend this contract when
/// business rules require operations that are not generic CRUD.
abstract interface class DomainRepository<T extends DomainEntity> {
  Future<T?> getById(String id);
  Future<List<T>> list();
  Future<void> save(T entity);
  Future<void> deleteById(String id);
}
