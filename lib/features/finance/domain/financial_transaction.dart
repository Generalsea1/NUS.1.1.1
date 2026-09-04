import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Financial transaction direction within the future Finance ledger.
enum FinancialTransactionType { income, expense }

/// Exact monetary value for Finance, expressed in integer minor units.
///
/// Amount is always non-negative. Transaction type determines cash-flow
/// direction, which keeps income and expense semantics explicit.
class FinancialTransaction implements DomainEntity {
  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
    required this.type,
    this.categoryId,
    this.description,
    this.sourceReference,
  })
  : assert(id != '', 'Transaction ID must not be empty.'),
        assert(accountId != '', 'Account ID must not be empty.'),
        assert(amountMinorUnits > 0, 'Transaction amount must be positive.'),
        assert(currencyCode != '', 'Currency code must not be empty.');

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
}

/// Repository boundary for future persisted Finance transactions.
abstract interface class FinancialTransactionRepository
    implements DomainRepository<FinancialTransaction> {}
