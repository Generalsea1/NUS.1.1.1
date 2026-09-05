import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// A financial obligation with exact integer minor-unit money.
class Bill implements DomainEntity {
  factory Bill({
    required String id,
    required String title,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime dueAt,
    bool isPaid = false,
  }) {
    final cleanId = id.trim();
    final cleanTitle = title.trim();
    final currency = currencyCode.trim().toUpperCase();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Bill ID must not be empty.');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Bill title must not be empty.');
    if (amountMinorUnits <= 0) throw ArgumentError.value(amountMinorUnits, 'amountMinorUnits', 'Bill amount must be greater than zero.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Currency code must be exactly three alphabetic characters.');
    }
    return Bill._(id: cleanId, title: cleanTitle, amountMinorUnits: amountMinorUnits, currencyCode: currency, dueAt: dueAt, isPaid: isPaid);
  }

  const Bill._({required this.id, required this.title, required this.amountMinorUnits, required this.currencyCode, required this.dueAt, required this.isPaid});

  @override final String id;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime dueAt;
  final bool isPaid;

  Bill copyWith({String? id, String? title, int? amountMinorUnits, String? currencyCode, DateTime? dueAt, bool? isPaid}) => Bill(
        id: id ?? this.id,
        title: title ?? this.title,
        amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
        currencyCode: currencyCode ?? this.currencyCode,
        dueAt: dueAt ?? this.dueAt,
        isPaid: isPaid ?? this.isPaid,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'amountMinorUnits': amountMinorUnits,
        'currencyCode': currencyCode,
        'dueAt': dueAt.toIso8601String(),
        'isPaid': isPaid,
      };

  factory Bill.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final amount = json['amountMinorUnits'];
    final currency = json['currencyCode'];
    final dueAt = json['dueAt'];
    final paid = json['isPaid'];
    if (id is! String || title is! String || amount is! int || currency is! String || dueAt is! String || paid is! bool) {
      throw const FormatException('Invalid Bill record.');
    }
    final parsedDueAt = DateTime.tryParse(dueAt);
    if (parsedDueAt == null) throw const FormatException('Invalid Bill dueAt.');
    try {
      return Bill(id: id, title: title, amountMinorUnits: amount, currencyCode: currency, dueAt: parsedDueAt, isPaid: paid);
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) => other is Bill && other.id == id && other.title == title && other.amountMinorUnits == amountMinorUnits && other.currencyCode == currencyCode && other.dueAt == dueAt && other.isPaid == isPaid;

  @override
  int get hashCode => Object.hash(id, title, amountMinorUnits, currencyCode, dueAt, isPaid);
}

abstract interface class BillRepository implements DomainRepository<Bill> {}
