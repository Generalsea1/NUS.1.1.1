import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Financial transaction direction within the future Finance ledger.
enum FinancialTransactionType { income, expense }

/// Exact monetary value for Finance, expressed in integer minor units.
///
/// Amount is always non-negative. Transaction type determines cash-flow
/// direction, which keeps income and expense semantics explicit.
class FinancialTransaction implements DomainEntity {
  factory FinancialTransaction({
    required String id,
    required String accountId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime occurredAt,
    required FinancialTransactionType type,
    String? categoryId,
    String? description,
    String? sourceReference,
  }) {
    final cleanId = id.trim();
    final cleanAccountId = accountId.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();

    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Transaction ID must not be empty.');
    }
    if (cleanAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Account ID must not be empty.',
      );
    }
    if (amountMinorUnits <= 0) {
      throw ArgumentError.value(
        amountMinorUnits,
        'amountMinorUnits',
        'Transaction amount must be positive.',
      );
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
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
      currencyCode: cleanCurrency,
      occurredAt: occurredAt,
      type: type,
      categoryId: _normalizeOptional(categoryId),
      description: _normalizeOptional(description),
      sourceReference: _normalizeOptional(sourceReference),
    );
  }

  const FinancialTransaction._({
    required this.id,
    required this.accountId,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
    required this.type,
    required this.categoryId,
    required this.description,
    required this.sourceReference,
  });

  @override
  final String id;
  final String accountId;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredAt;
  final FinancialTransactionType type;
  final String? categoryId;
  final String? description;

  /// Optional identity of the source record, e.g. an Expense or Bill ID.
  /// The referenced domain owns that record; this transaction does not.
  final String? sourceReference;

  /// Signed minor-unit delta suitable for net cash-flow calculations.
  int get signedMinorUnits =>
      type == FinancialTransactionType.income
          ? amountMinorUnits
          : -amountMinorUnits;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'accountId': accountId,
        'amountMinorUnits': amountMinorUnits,
        'currencyCode': currencyCode,
        'occurredAt': occurredAt.toIso8601String(),
        'type': type.name,
        'categoryId': categoryId,
        'description': description,
        'sourceReference': sourceReference,
      };

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }
}

/// Repository boundary for future persisted Finance transactions.
abstract interface class FinancialTransactionRepository
    implements DomainRepository<FinancialTransaction> {}
