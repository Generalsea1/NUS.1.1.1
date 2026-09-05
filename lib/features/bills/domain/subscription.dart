import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Cadence describes the billing interval without calculating future occurrences.
enum SubscriptionCadence { weekly, monthly, quarterly, yearly }

/// A recurring financial obligation. Occurrence calculation belongs to the
/// future central recurrence engine, not this domain entity.
class Subscription implements DomainEntity {
  factory Subscription({
    required String id,
    required String title,
    required int amountMinorUnits,
    required String currencyCode,
    required SubscriptionCadence cadence,
    required DateTime nextDueAt,
    bool isArchived = false,
  }) {
    final cleanId = id.trim();
    final cleanTitle = title.trim();
    final currency = currencyCode.trim().toUpperCase();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Subscription ID must not be empty.');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Subscription title must not be empty.');
    if (amountMinorUnits <= 0) {
      throw ArgumentError.value(amountMinorUnits, 'amountMinorUnits', 'Subscription amount must be greater than zero.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Currency code must be exactly three alphabetic characters.');
    }
    return Subscription._(
      id: cleanId,
      title: cleanTitle,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currency,
      cadence: cadence,
      nextDueAt: nextDueAt,
      isArchived: isArchived,
    );
  }

  const Subscription._({
    required this.id,
    required this.title,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.cadence,
    required this.nextDueAt,
    required this.isArchived,
  });

  @override
  final String id;
  final String title;
  final int amountMinorUnits;
  final String currencyCode;
  final SubscriptionCadence cadence;
  final DateTime nextDueAt;
  final bool isArchived;

  Subscription copyWith({
    String? id,
    String? title,
    int? amountMinorUnits,
    String? currencyCode,
    SubscriptionCadence? cadence,
    DateTime? nextDueAt,
    bool? isArchived,
  }) => Subscription(
        id: id ?? this.id,
        title: title ?? this.title,
        amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
        currencyCode: currencyCode ?? this.currencyCode,
        cadence: cadence ?? this.cadence,
        nextDueAt: nextDueAt ?? this.nextDueAt,
        isArchived: isArchived ?? this.isArchived,
      );

  Subscription archive() => copyWith(isArchived: true);
  Subscription unarchive() => copyWith(isArchived: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'amountMinorUnits': amountMinorUnits,
        'currencyCode': currencyCode,
        'cadence': cadence.name,
        'nextDueAt': nextDueAt.toIso8601String(),
        'isArchived': isArchived,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final amount = json['amountMinorUnits'];
    final currency = json['currencyCode'];
    final cadenceValue = json['cadence'];
    final nextDueAt = json['nextDueAt'];
    final archived = json['isArchived'];
    if (id is! String ||
        title is! String ||
        amount is! int ||
        currency is! String ||
        cadenceValue is! String ||
        nextDueAt is! String ||
        archived is! bool) {
      throw const FormatException('Invalid Subscription record.');
    }
    SubscriptionCadence? cadence;
    for (final value in SubscriptionCadence.values) {
      if (value.name == cadenceValue) {
        cadence = value;
        break;
      }
    }
    final parsedNextDueAt = DateTime.tryParse(nextDueAt);
    if (cadence == null) throw const FormatException('Invalid Subscription cadence.');
    if (parsedNextDueAt == null) throw const FormatException('Invalid Subscription nextDueAt.');
    try {
      return Subscription(
        id: id,
        title: title,
        amountMinorUnits: amount,
        currencyCode: currency,
        cadence: cadence,
        nextDueAt: parsedNextDueAt,
        isArchived: archived,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Subscription &&
      other.id == id &&
      other.title == title &&
      other.amountMinorUnits == amountMinorUnits &&
      other.currencyCode == currencyCode &&
      other.cadence == cadence &&
      other.nextDueAt == nextDueAt &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        amountMinorUnits,
        currencyCode,
        cadence,
        nextDueAt,
        isArchived,
      );
}

abstract interface class SubscriptionRepository implements DomainRepository<Subscription> {}
