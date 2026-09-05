import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// The transaction direction a financial category can classify.
enum FinancialCategoryDirection { income, expense }

/// Stable financial category identity referenced by transactions.
class FinancialCategory implements DomainEntity {
  factory FinancialCategory({
    required String id,
    required String name,
    required FinancialCategoryDirection direction,
    bool isArchived = false,
  }) {
    final cleanId = id.trim();
    final cleanName = name.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Category ID must not be empty.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name must not be empty.');
    }
    return FinancialCategory._(
      id: cleanId,
      name: cleanName,
      direction: direction,
      isArchived: isArchived,
    );
  }

  const FinancialCategory._({
    required this.id,
    required this.name,
    required this.direction,
    required this.isArchived,
  });

  @override
  final String id;
  final String name;
  final FinancialCategoryDirection direction;
  final bool isArchived;

  FinancialCategory copyWith({
    String? id,
    String? name,
    FinancialCategoryDirection? direction,
    bool? isArchived,
  }) =>
      FinancialCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        direction: direction ?? this.direction,
        isArchived: isArchived ?? this.isArchived,
      );

  FinancialCategory archive() => copyWith(isArchived: true);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'direction': direction.name,
        'isArchived': isArchived,
      };

  factory FinancialCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final direction = json['direction'];
    final isArchived = json['isArchived'];

    if (id is! String || name is! String || direction is! String) {
      throw const FormatException('Financial category fields have invalid types.');
    }
    if (isArchived != null && isArchived is! bool) {
      throw const FormatException('Financial category isArchived must be a boolean.');
    }

    FinancialCategoryDirection? parsedDirection;
    for (final value in FinancialCategoryDirection.values) {
      if (value.name == direction) {
        parsedDirection = value;
        break;
      }
    }
    if (parsedDirection == null) {
      throw const FormatException('Unknown financial category direction.');
    }

    try {
      return FinancialCategory(
        id: id,
        name: name,
        direction: parsedDirection,
        isArchived: isArchived as bool? ?? false,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialCategory &&
      other.id == id &&
      other.name == name &&
      other.direction == direction &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(id, name, direction, isArchived);
}

/// Repository boundary for financial categories.
abstract interface class FinancialCategoryRepository
    implements DomainRepository<FinancialCategory> {
  Future<void> archiveById(String id);
}
