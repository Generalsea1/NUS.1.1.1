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
      list = ShoppingList(id: _newId(), name: name);
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
    final existing = await _requireList(listId);
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Shopping item name must not be empty.');
    }

    // Quick Add can be retried after transient UI/repository failures. Treat
    // an identical active item as the same logical request rather than adding
    // a duplicate row to the aggregate. Explicit quantity changes are kept as
    // a distinct update path through [updateItem].
    final existingActive = existing.items.where((item) =>
        !item.isCompleted &&
        item.name.trim().toLowerCase() == cleanName.toLowerCase());
    if (existingActive.isNotEmpty) return existing;

    ShoppingItem item;
    do {
      item = ShoppingItem(id: _newId(), name: cleanName, quantity: quantity);
    } while (existing.items.any((current) => current.id == item.id));

    final updated = existing.addItem(item);
    await _repository.save(updated);
    return updated;
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

  static String _newId() {
    String hex(int width) =>
        _random.nextInt(1 << (width * 4)).toRadixString(16).padLeft(width, '0');

    final p1 = hex(8);
    final p2 = hex(4);
    final p3 = (0x4000 | _random.nextInt(0x1000)).toRadixString(16).padLeft(4, '0');
    final p4 = (0x8000 | _random.nextInt(0x4000)).toRadixString(16).padLeft(4, '0');
    final p5 = hex(12);
    return '$p1-$p2-$p3-$p4-$p5';
  }
}
