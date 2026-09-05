import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Indicates whether the user owes money or is owed money.
enum DebtDirection {
  owedByUser,
  owedToUser,
}

/// Aggregate representing a personal debt obligation/receivable.
///
/// Money is stored exactly in integer minor units. Settlement entries are
/// persisted separately so this aggregate does not contain an embedded,
/// independently editable settlement history.
class Debt implements DomainEntity {
  factory Debt({
    required String id,
    required String title,
    required DebtDirection direction,
    required int principalMinorUnits,
    required String currencyCode,
    String? counterparty,
    DateTime? dueAt,
    int settledMinorUnits = 0,
    bool isArchived = false,
  }) {
    final cleanId = id.trim();
    final cleanTitle = title.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    final cleanCounterparty = counterparty?.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Debt ID must not be empty.');
    }
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Debt title must not be empty.',
      );
    }
    if (principalMinorUnits <= 0) {
      throw ArgumentError.value(
        principalMinorUnits,
        'principalMinorUnits',
        'Debt principal must be greater than zero.',
      );
    }
    if (settledMinorUnits < 0 || settledMinorUnits > principalMinorUnits) {
      throw ArgumentError.value(
        settledMinorUnits,
        'settledMinorUnits',
        'Settled amount must be between zero and the principal.',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code must be exactly three alphabetic characters.',
      );
    }
    if (cleanCounterparty != null && cleanCounterparty.isEmpty) {
      throw ArgumentError.value(
        counterparty,
        'counterparty',
        'Counterparty must not be blank when supplied.',
      );
    }

    return Debt._(
      id: cleanId,
      title: cleanTitle,
      direction: direction,
      principalMinorUnits: principalMinorUnits,
      currencyCode: cleanCurrency,
      counterparty: cleanCounterparty,
      dueAt: dueAt,
      settledMinorUnits: settledMinorUnits,
      isArchived: isArchived,
    );
  }

  const Debt._({
    required this.id,
    required this.title,
    required this.direction,
    required this.principalMinorUnits,
    required this.currencyCode,
    required this.counterparty,
    required this.dueAt,
    required this.settledMinorUnits,
    required this.isArchived,
  });

  @override
  final String id;
  final String title;
  final DebtDirection direction;
  final int principalMinorUnits;
  final String currencyCode;
  final String? counterparty;
  final DateTime? dueAt;
  final int settledMinorUnits;
  final bool isArchived;

  int get outstandingMinorUnits =>
      principalMinorUnits - settledMinorUnits;

  bool get isSettled => outstandingMinorUnits == 0;

  Debt copyWith({
    String? id,
    String? title,
    DebtDirection? direction,
    int? principalMinorUnits,
    String? currencyCode,
    Object? counterparty = _unset,
    Object? dueAt = _unset,
    int? settledMinorUnits,
    bool? isArchived,
  }) => Debt(
        id: id ?? this.id,
        title: title ?? this.title,
        direction: direction ?? this.direction,
        principalMinorUnits:
            principalMinorUnits ?? this.principalMinorUnits,
        currencyCode: currencyCode ?? this.currencyCode,
        counterparty: identical(counterparty, _unset)
            ? this.counterparty
            : counterparty as String?,
        dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
        settledMinorUnits: settledMinorUnits ?? this.settledMinorUnits,
        isArchived: isArchived ?? this.isArchived,
      );

  Debt archive() => copyWith(isArchived: true);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'direction': direction.name,
        'principalMinorUnits': principalMinorUnits,
        'currencyCode': currencyCode,
        if (counterparty != null) 'counterparty': counterparty,
        if (dueAt != null) 'dueAt': dueAt!.toIso8601String(),
        'settledMinorUnits': settledMinorUnits,
        'isArchived': isArchived,
      };

  factory Debt.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final direction = json['direction'];
    final principal = json['principalMinorUnits'];
    final currency = json['currencyCode'];
    final counterparty = json['counterparty'];
    final dueAt = json['dueAt'];
    final settled = json['settledMinorUnits'];
    final archived = json['isArchived'];

    if (id is! String ||
        title is! String ||
        direction is! String ||
        principal is! int ||
        currency is! String ||
        settled is! int ||
        archived is! bool) {
      throw const FormatException('Invalid Debt record.');
    }
    if (counterparty != null && counterparty is! String) {
      throw const FormatException('Debt counterparty must be a string.');
    }
    if (dueAt != null && dueAt is! String) {
      throw const FormatException('Debt dueAt must be a string.');
    }

    final parsedDueAt = dueAt == null ? null : DateTime.tryParse(dueAt);
    if (dueAt != null && parsedDueAt == null) {
      throw const FormatException('Invalid Debt dueAt.');
    }

    final debtDirection = switch (direction.trim().toLowerCase()) {
      'owedbyuser' || 'owed_by_user' => DebtDirection.owedByUser,
      'owedtouser' || 'owed_to_user' => DebtDirection.owedToUser,
      _ => throw const FormatException('Debt direction is unsupported.'),
    };

    try {
      return Debt(
        id: id,
        title: title,
        direction: debtDirection,
        principalMinorUnits: principal,
        currencyCode: currency,
        counterparty: counterparty as String?,
        dueAt: parsedDueAt,
        settledMinorUnits: settled,
        isArchived: archived,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Debt &&
      other.id == id &&
      other.title == title &&
      other.direction == direction &&
      other.principalMinorUnits == principalMinorUnits &&
      other.currencyCode == currencyCode &&
      other.counterparty == counterparty &&
      other.dueAt == dueAt &&
      other.settledMinorUnits == settledMinorUnits &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        direction,
        principalMinorUnits,
        currencyCode,
        counterparty,
        dueAt,
        settledMinorUnits,
        isArchived,
      );
}

abstract interface class DebtRepository implements DomainRepository<Debt> {
  Future<void> archiveById(String id);
}

const _unset = Object();
