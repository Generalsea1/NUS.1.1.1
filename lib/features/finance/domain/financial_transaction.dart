import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Canonical financial transaction entry for the Finance ledger.
///
/// Transactions store signed exact minor units: positive values represent
/// income and negative values represent expense/outflow.
class FinancialTransaction implements DomainEntity {
  factory FinancialTransaction({
    required String id,
    required String accountId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime occurredOn,
    String? categoryId,
    String? counterparty,
    String? note,
    String? externalReference,
  }) {
    final cleanId = id.trim();
    final cleanAccountId = accountId.trim();
    final normalizedCurrency = currencyCode.trim().toUpperCase();

    if (cleanId.isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'Financial transaction ID must not be empty.',
      );
    }
    if (cleanAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Financial transaction account ID must not be empty.',
      );
    }
    if (amountMinorUnits == 0) {
      throw ArgumentError.value(
        amountMinorUnits,
        'amountMinorUnits',
        'Financial transaction amount must not be zero.',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code must be exactly three alphabetic characters.',
      );
    }

    return FinancialTransaction._(
      id: cleanId,
      accountId: cleanAccountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: normalizedCurrency,
      occurredOn: occurredOn,
      categoryId: _normalizeOptional(categoryId),
      counterparty: _normalizeOptional(counterparty),
      note: _normalizeOptional(note),
      externalReference: _normalizeOptional(externalReference),
    );
  }

  const FinancialTransaction._({
    required this.id,
    required this.accountId,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredOn,
    required this.categoryId,
    required this.counterparty,
    required this.note,
    required this.externalReference,
  });

  @override
  final String id;
  final String accountId;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredOn;
  final String? categoryId;
  final String? counterparty;
  final String? note;
  final String? externalReference;

  bool get isIncome => amountMinorUnits > 0;
  bool get isExpense => amountMinorUnits < 0;

  FinancialTransaction copyWith({
    String? id,
    String? accountId,
    int? amountMinorUnits,
    String? currencyCode,
    DateTime? occurredOn,
    String? categoryId,
    String? counterparty,
    String? note,
    String? externalReference,
  }) =>
      FinancialTransaction(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
        currencyCode: currencyCode ?? this.currencyCode,
        occurredOn: occurredOn ?? this.occurredOn,
        categoryId: categoryId ?? this.categoryId,
        counterparty: counterparty ?? this.counterparty,
        note: note ?? this.note,
        externalReference: externalReference ?? this.externalReference,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'accountId': accountId,
        'amountMinorUnits': amountMinorUnits,
        'currencyCode': currencyCode,
        'occurredOn': occurredOn.toIso8601String(),
        'categoryId': categoryId,
        'counterparty': counterparty,
        'note': note,
        'externalReference': externalReference,
      };

  factory FinancialTransaction.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final accountId = json['accountId'];
    final amountMinorUnits = json['amountMinorUnits'];
    final currencyCode = json['currencyCode'];
    final occurredOn = json['occurredOn'];

    if (id is! String) {
      throw const FormatException('Financial transaction id must be a string.');
    }
    if (accountId is! String) {
      throw const FormatException(
        'Financial transaction accountId must be a string.',
      );
    }
    if (amountMinorUnits is! int) {
      throw const FormatException(
        'Financial transaction amountMinorUnits must be an integer.',
      );
    }
    if (currencyCode is! String) {
      throw const FormatException(
        'Financial transaction currencyCode must be a string.',
      );
    }
    if (occurredOn is! String) {
      throw const FormatException(
        'Financial transaction occurredOn must be a string.',
      );
    }

    final parsedOccurredOn = DateTime.tryParse(occurredOn);
    if (parsedOccurredOn == null) {
      throw const FormatException(
        'Financial transaction occurredOn must be a valid ISO-8601 date.',
      );
    }

    final categoryId = _readOptionalString(json, 'categoryId');
    final counterparty = _readOptionalString(json, 'counterparty');
    final note = _readOptionalString(json, 'note');
    final externalReference = _readOptionalString(json, 'externalReference');

    try {
      return FinancialTransaction(
        id: id,
        accountId: accountId,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
        occurredOn: parsedOccurredOn,
        categoryId: categoryId,
        counterparty: counterparty,
        note: note,
        externalReference: externalReference,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  static String? _readOptionalString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException(
        'Financial transaction $key must be a string or null.',
      );
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is FinancialTransaction &&
      other.id == id &&
      other.accountId == accountId &&
      other.amountMinorUnits == amountMinorUnits &&
      other.currencyCode == currencyCode &&
      other.occurredOn == occurredOn &&
      other.categoryId == categoryId &&
      other.counterparty == counterparty &&
      other.note == note &&
      other.externalReference == externalReference;

  @override
  int get hashCode => Object.hash(
        id,
        accountId,
        amountMinorUnits,
        currencyCode,
        occurredOn,
        categoryId,
        counterparty,
        note,
        externalReference,
      );
}

/// Repository boundary for Finance transactions.
abstract interface class FinancialTransactionRepository
    implements DomainRepository<FinancialTransaction> {}
