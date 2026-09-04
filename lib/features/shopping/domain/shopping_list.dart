import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';
import 'shopping_item.dart';

/// Aggregate root for Smart Shopping.
///
/// All [ShoppingItem] children are owned by this aggregate and are persisted
/// as one complete record. Items have no independent repository boundary.
class ShoppingList implements DomainEntity {
  factory ShoppingList({
    required String id,
    required String name,
    List<ShoppingItem> items = const <ShoppingItem>[],
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Shopping list ID must not be empty.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Shopping list name must not be empty.');
    }

    final copy = List<ShoppingItem>.of(items);
    final ids = <String>{};
    for (final item in copy) {
      if (!ids.add(item.id)) {
        throw ArgumentError.value(
          item.id,
          'items',
          'Shopping item IDs must be unique within a list.',
        );
      }
    }

    return ShoppingList._(
      id: id,
      name: cleanName,
      items: List.unmodifiable(copy),
    );
  }

  const ShoppingList._({
    required this.id,
    required this.name,
    required this.items,
  });

  @override
  final String id;
  final String name;
  final List<ShoppingItem> items;

  ShoppingList copyWith({
    String? id,
    String? name,
    List<ShoppingItem>? items,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  ShoppingList addItem(ShoppingItem item) {
    if (items.any((existing) => existing.id == item.id)) {
      throw StateError('Shopping item ID already exists: ${item.id}');
    }
    return copyWith(items: <ShoppingItem>[...items, item]);
  }

  ShoppingList updateItem(ShoppingItem item) {
    final index = items.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      throw StateError('Shopping item does not exist: ${item.id}');
    }
    final updated = List<ShoppingItem>.of(items)..[index] = item;
    return copyWith(items: updated);
  }

  ShoppingList removeItem(String itemId) {
    final updated = List<ShoppingItem>.of(items)
      ..removeWhere((item) => item.id == itemId);
    return copyWith(items: updated);
  }

  ShoppingList setItemCompleted(String itemId, bool isCompleted) {
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      throw StateError('Shopping item does not exist: $itemId');
    }
    final updated = List<ShoppingItem>.of(items)
      ..[index] = items[index].copyWith(isCompleted: isCompleted);
    return copyWith(items: updated);
  }

  ShoppingList toggleItem(String itemId) {
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) {
      throw StateError('Shopping item does not exist: $itemId');
    }
    return setItemCompleted(itemId, !items[index].isCompleted);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final rawItems = json['items'];

    if (id is! String || name is! String) {
      throw const FormatException('Shopping list requires string id and name.');
    }
    if (rawItems is! List) {
      throw const FormatException('Shopping list items must be a JSON array.');
    }

    final items = <ShoppingItem>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const FormatException('Shopping list contains a malformed item.');
      }
      items.add(ShoppingItem.fromJson(Map<String, dynamic>.from(rawItem)));
    }

    return ShoppingList(id: id, name: name, items: items);
  }
}

/// Repository boundary for the [ShoppingList] aggregate.
abstract interface class ShoppingRepository
    implements DomainRepository<ShoppingList> {}
