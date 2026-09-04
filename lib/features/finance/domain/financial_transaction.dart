import '../../../core/domain/domain_entity.dart';

/// Canonical financial transaction entry used by the future Finance ledger.
///
/// The transaction stores exact money through integer minor units and keeps
/// account/category references opaque. It does not depend on Expense or Bill
/// domain objects, which keeps cross-domain ownership explicit.
class FinancialTransaction implements DomainEntity {
  const FinancialTransaction({
    required this.id,
    required this.accountId,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredOn,
    this.categoryId,
    this.counterparty,
    this.note,
    this.externalReference,
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
  }) => FinancialTransaction(
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
}

/// Repository boundary for Finance transactions.
abstract interface class FinancialTransactionRepository {}
