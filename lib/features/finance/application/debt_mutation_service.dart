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

class DebtPrincipalBelowSettledException implements Exception {
  const DebtPrincipalBelowSettledException({
    required this.principalMinorUnits,
    required this.settledMinorUnits,
  });
  final int principalMinorUnits;
  final int settledMinorUnits;

  @override
  String toString() =>
      'Debt principal $principalMinorUnits is below settled amount $settledMinorUnits.';
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

    final settled = await _settledMinorUnitsFor(existing);
    if (debt.principalMinorUnits < settled) {
      throw DebtPrincipalBelowSettledException(
        principalMinorUnits: debt.principalMinorUnits,
        settledMinorUnits: settled,
      );
    }
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

    final cleanSettlementId = settlementId.trim();
    final existingSettlement =
        await _settlementRepository.getById(cleanSettlementId);
    if (existingSettlement != null) {
      throw DebtSettlementDuplicateIdException(cleanSettlementId);
    }

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

    final settledMinorUnits = await _settledMinorUnitsFor(debt);
    final outstandingMinorUnits =
        debt.principalMinorUnits - settledMinorUnits;
    if (outstandingMinorUnits < 0) {
      throw DebtPrincipalBelowSettledException(
        principalMinorUnits: debt.principalMinorUnits,
        settledMinorUnits: settledMinorUnits,
      );
    }
    if (amountMinorUnits > outstandingMinorUnits) {
      throw DebtSettlementExceedsOutstandingException(
        requestedMinorUnits: amountMinorUnits,
        outstandingMinorUnits: outstandingMinorUnits,
      );
    }

    final settlement = DebtSettlement(
      id: cleanSettlementId,
      debtId: cleanDebtId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: normalizedCurrency,
      settledAt: settledAt,
      note: note,
      financialTransactionId: financialTransactionId,
    );

    // The settlement record is the source of truth. The Debt aggregate is
    // deliberately not mutated with a duplicated settled counter.
    await _settlementRepository.save(settlement);
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

  Future<int> _settledMinorUnits(Debt debt) async {
    var total = 0;
    for (final settlement in await settlementsForDebt(debt.id)) {
      if (settlement.currencyCode != debt.currencyCode) {
        throw DebtSettlementCurrencyMismatchException(
          debtCurrency: debt.currencyCode,
          settlementCurrency: settlement.currencyCode,
        );
      }
      total += settlement.amountMinorUnits;
    }
    return total;
  }
}
