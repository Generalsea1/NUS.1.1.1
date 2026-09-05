import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Immutable record of a settlement applied to a debt.
class DebtSettlement implements DomainEntity {
  factory DebtSettlement({
    required String id,
    required String debtId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime settledAt,
    String? note,
    String? financialTransactionId,
  }) {
    final cleanId = id.trim();
    final cleanDebtId = debtId.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    final cleanNote = note?.trim();
    final cleanTransactionId = financialTransactionId?.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Settlement ID must not be empty.');
    }
    if (cleanDebtId.isEmpty) {
      throw ArgumentError.value(
        debtId,
        'debtId',
        'Settlement debtId must not be empty.',
      );
    }
    if (amountMinorUnits <= 0) {
      throw ArgumentError.value(
        amountMinorUnits,
        'amountMinorUnits',
        'Settlement amount must be greater than zero.',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code must be exactly three alphabetic characters.',
      );
    }
    if (cleanNote != null && cleanNote.isEmpty) {
      throw ArgumentError.value(
        note,
        'note',
        'Settlement note must not be blank when supplied.',
      );
    }
    if (cleanTransactionId != null && cleanTransactionId.isEmpty) {
      throw ArgumentError.value(
        financialTransactionId,
        'financialTransactionId',
        'Financial transaction ID must not be blank when supplied.',
      );
    }

    return DebtSettlement._(
      id: cleanId,
      debtId: cleanDebtId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: cleanCurrency,
      settledAt: settledAt,
      note: cleanNote,
      financialTransactionId: cleanTransactionId,
    );
  }

  const DebtSettlement._({
    required this.id,
    required this.debtId,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.settledAt,
    required this.note,
    required this.financialTransactionId,
  });

  @override
  final String id;
  final String debtId;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime settledAt;
  final String? note;
  final String? financialTransactionId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'debtId': debtId,
        'amountMinorUnits': amountMinorUnits,
        'currencyCode': currencyCode,
        'settledAt': settledAt.toIso8601String(),
        if (note != null) 'note': note,
        if (financialTransactionId != null)
          'financialTransactionId': financialTransactionId,
      };

  factory DebtSettlement.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final debtId = json['debtId'];
    final amount = json['amountMinorUnits'];
    final currency = json['currencyCode'];
    final settledAt = json['settledAt'];
    final note = json['note'];
    final transactionId = json['financialTransactionId'];

    if (id is! String ||
        debtId is! String ||
        amount is! int ||
        currency is! String ||
        settledAt is! String) {
      throw const FormatException('Invalid DebtSettlement record.');
    }
    if (note != null && note is! String) {
      throw const FormatException('DebtSettlement note must be a string.');
    }
    if (transactionId != null && transactionId is! String) {
      throw const FormatException(
        'DebtSettlement financialTransactionId must be a string.',
      );
    }
    final parsedSettledAt = DateTime.tryParse(settledAt);
    if (parsedSettledAt == null) {
      throw const FormatException('Invalid DebtSettlement settledAt.');
    }

    try {
      return DebtSettlement(
        id: id,
        debtId: debtId,
        amountMinorUnits: amount,
        currencyCode: currency,
        settledAt: parsedSettledAt,
        note: note as String?,
        financialTransactionId: transactionId as String?,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DebtSettlement &&
      other.id == id &&
      other.debtId == debtId &&
      other.amountMinorUnits == amountMinorUnits &&
      other.currencyCode == currencyCode &&
      other.settledAt == settledAt &&
      other.note == note &&
      other.financialTransactionId == financialTransactionId;

  @override
  int get hashCode => Object.hash(
        id,
        debtId,
        amountMinorUnits,
        currencyCode,
        settledAt,
        note,
        financialTransactionId,
      );
}

abstract interface class DebtSettlementRepository
    implements DomainRepository<DebtSettlement> {}
