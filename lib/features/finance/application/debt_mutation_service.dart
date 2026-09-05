import '../domain/debt.dart';
import '../domain/debt_settlement.dart';

class DebtDuplicateIdException implements Exception {
  const DebtDuplicateIdException(this.id);
  final String id;

  @override
  String toString() => 'Debt ID already exists: $id';
}

class DebtNotFoundException implements Exception {
  const DebtNotFoundException(this.id);
  final String id;

  @override
  String toString() => 'Debt not found: $id';
}

class DebtArchivedException implements Exception {
  const DebtArchivedException(this.id);
  final String id;

  @override
  String toString() => 'Debt is archived: $id';
}

class DebtSettlementDuplicateIdException implements Exception {
  const DebtSettlementDuplicateIdException(this.id);
  final String id;

  @override
  String toString() => 'Debt settlement ID already exists: $id';
}

class DebtSettlementCurrencyMismatchException implements Exception {
  const DebtSettlementCurrencyMismatchException({
    required this.debtCurrency,
    required this.settlementCurrency,
  });
  final String debtCurrency;
  final String settlementCurrency;

  @override
  String toString() =>
      'Debt settlement currency $settlementCurrency does not match debt currency $debtCurrency.';
}

class DebtSettlementExceedsOutstandingException implements Exception {
  const DebtSettlementExceedsOutstandingException({
    required this.requestedMinorUnits,
    required this.outstandingMinorUnits,
  });
  final int requestedMinorUnits;
  final int outstandingMinorUnits;

  @override
  String toString() =>
      'Settlement $requestedMinorUnits exceeds outstanding amount $outstandingMinorUnits.';
}

/// Application boundary for debt lifecycle and settlement.
class DebtMutationService {
  const DebtMutationService({
    required DebtRepository debtRepository,
    required DebtSettlementRepository settlementRepository,
  })  : _debtRepository = debtRepository,
        _settlementRepository = settlementRepository;

  final DebtRepository _debtRepository;
  final DebtSettlementRepository _settlementRepository;

  Future<void> createDebt(Debt debt) async {
    final existing = await _debtRepository.getById(debt.id);
    if (existing != null) throw DebtDuplicateIdException(debt.id);
    await _debtRepository.save(debt);
  }

  Future<void> updateDebt(Debt debt) async {
    final existing = await _debtRepository.getById(debt.id);
    if (existing == null) throw DebtNotFoundException(debt.id);
    await _debtRepository.save(debt);
  }

  Future<void> archiveDebt(String debtId) async {
    final cleanId = debtId.trim();
    if (cleanId.isEmpty) throw DebtNotFoundException(debtId);
    final existing = await _debtRepository.getById(cleanId);
    if (existing == null) throw DebtNotFoundException(cleanId);
    await _debtRepository.archiveById(cleanId);
  }

  Future<DebtSettlement> settleDebt({
    required String settlementId,
    required String debtId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime settledAt,
    String? note,
    String? financialTransactionId,
  }) async {
    final cleanDebtId = debtId.trim();
    final debt = await _debtRepository.getById(cleanDebtId);
    if (debt == null) throw DebtNotFoundException(cleanDebtId);
    if (debt.isArchived) throw DebtArchivedException(cleanDebtId);

    final normalizedCurrency = currencyCode.trim().toUpperCase();
    if (normalizedCurrency != debt.currencyCode) {
      throw DebtSettlementCurrencyMismatchException(
        debtCurrency: debt.currencyCode,
        settlementCurrency: normalizedCurrency,
      );
    }
    if (amountMinorUnits <= 0) {
      throw ArgumentError.value(
        amountMinorUnits,
        'amountMinorUnits',
        'Settlement amount must be greater than zero.',
      );
    }
    if (amountMinorUnits > debt.outstandingMinorUnits) {
      throw DebtSettlementExceedsOutstandingException(
        requestedMinorUnits: amountMinorUnits,
        outstandingMinorUnits: debt.outstandingMinorUnits,
      );
    }

    final existingSettlement =
        await _settlementRepository.getById(settlementId.trim());
    if (existingSettlement != null) {
      throw DebtSettlementDuplicateIdException(settlementId.trim());
    }

    final settlement = DebtSettlement(
      id: settlementId,
      debtId: cleanDebtId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: normalizedCurrency,
      settledAt: settledAt,
      note: note,
      financialTransactionId: financialTransactionId,
    );

    final updatedDebt = debt.copyWith(
      settledMinorUnits: debt.settledMinorUnits + amountMinorUnits,
    );

    await _settlementRepository.save(settlement);
    await _debtRepository.save(updatedDebt);
    return settlement;
  }

  Future<List<DebtSettlement>> settlementsForDebt(String debtId) async {
    final cleanDebtId = debtId.trim();
    if (cleanDebtId.isEmpty) return const [];
    final settlements = await _settlementRepository.list();
    return List.unmodifiable(
      settlements.where((settlement) => settlement.debtId == cleanDebtId),
    );
  }
}
