import 'dart:math';

import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// Application boundary for Smart Shopping use-case orchestration.
///
/// This service coordinates aggregate loading, domain operations, and
/// repository persistence. It intentionally knows nothing about Flutter UI or
/// the concrete persistence implementation.
class ShoppingLifecycleService {
  ShoppingLifecycleService({required ShoppingRepository repository})
      : _repository = repository;

  final ShoppingRepository _repository;
  static final Random _random = Random.secure();

  Future<ShoppingList> createList({required String name}) async {
    ShoppingList list;
    do {
      list = ShoppingList(id: _newId('sl'), name: name);
    } while (await _repository.getById(list.id) != null);

    await _repository.save(list);
    return list;
  }

  Future<ShoppingList?> getList(String listId) => _repository.getById(listId);

  Future<List<ShoppingList>> getAllLists() => _repository.list();

  Future<ShoppingList> updateList(
    String listId, {
    required String name,
  }) async {
    final existing = await _requireList(listId);
    final updated = existing.copyWith(name: name);
    await _repository.save(updated);
    return updated;
  }

  Future<void> deleteList(String listId) async {
    await _requireList(listId);
    await _repository.deleteById(listId);
  }

  Future<ShoppingList> addItem(
    String listId, {
    required String name,
    String? quantity,
  }) async {
    var list = await _requireList(listId);
    ShoppingItem item;
    do {
      item = ShoppingItem(id: _newId('si'), name: name, quantity: quantity);
    } while (list.items.any((existing) => existing.id == item.id));

    list = list.addItem(item);
    await _repository.save(list);
    return list;
  }

  Future<ShoppingList> updateItem(
    String listId,
    ShoppingItem item,
  ) async {
    final existing = await _requireList(listId);
    final updated = existing.updateItem(item);
    await _repository.save(updated);
    return updated;
  }

  Future<ShoppingList> removeItem(
    String listId,
    String itemId,
  ) async {
    final existing = await _requireList(listId);
    final updated = existing.removeItem(itemId);
    await _repository.save(updated);
    return updated;
  }

  Future<ShoppingList> setItemCompleted(
    String listId,
    String itemId,
    bool isCompleted,
  ) async {
    final existing = await _requireList(listId);
    final updated = existing.setItemCompleted(itemId, isCompleted);
    await _repository.save(updated);
    return updated;
  }

  Future<ShoppingList> toggleItemCompletion(
    String listId,
    String itemId,
  ) async {
    final existing = await _requireList(listId);
    final updated = existing.toggleItem(itemId);
    await _repository.save(updated);
    return updated;
  }

  Future<ShoppingList> _requireList(String listId) async {
    final list = await _repository.getById(listId);
    if (list == null) {
      throw StateError('Shopping list does not exist: $listId');
    }
    return list;
  }

  static String _newId(String prefix) {
    final first = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final second = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$prefix-$first$second';
  }
}
