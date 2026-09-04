import '../../../core/domain/domain_entity.dart';

/// Owned child entity of a [ShoppingList] aggregate.
///
/// Quantity is organizer text only. It is deliberately not interpreted as a
/// number and has no unit-conversion behavior in this phase.
class ShoppingItem implements DomainEntity {
  factory ShoppingItem({
    required String id,
    required String name,
    String? quantity,
    bool isCompleted = false,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Shopping item ID must not be empty.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Shopping item name must not be empty.');
    }

    return ShoppingItem._(
      id: id,
      name: cleanName,
      quantity: quantity,
      isCompleted: isCompleted,
    );
  }

  const ShoppingItem._({
    required this.id,
    required this.name,
    required this.quantity,
    required this.isCompleted,
  });

  @override
  final String id;
  final String name;
  final String? quantity;
  final bool isCompleted;

  ShoppingItem copyWith({
    String? id,
    String? name,
    String? quantity,
    bool clearQuantity = false,
    bool? isCompleted,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: clearQuantity ? null : (quantity ?? this.quantity),
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'quantity': quantity,
        'isCompleted': isCompleted,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final quantity = json['quantity'];
    final isCompleted = json['isCompleted'];

    if (id is! String || name is! String) {
      throw const FormatException('Shopping item requires string id and name.');
    }
    if (quantity != null && quantity is! String) {
      throw const FormatException('Shopping item quantity must be a string or null.');
    }
    if (isCompleted != null && isCompleted is! bool) {
      throw const FormatException('Shopping item isCompleted must be a boolean.');
    }

    return ShoppingItem(
      id: id,
      name: name,
      quantity: quantity as String?,
      isCompleted: isCompleted as bool? ?? false,
    );
  }
}
