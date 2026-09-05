import '../domain/debt.dart';
import '../domain/debt_settlement.dart';

class DebtSettlementRecordCurrencyMismatchException implements Exception {
  const DebtSettlementRecordCurrencyMismatchException({
    required this.debtId,
    required this.debtCurrency,
    required this.settlementCurrency,
  });

  final String debtId;
  final String debtCurrency;
  final String settlementCurrency;

  @override
  String toString() =>
      'Debt $debtId contains a settlement in $settlementCurrency; expected $debtCurrency.';
}

class DebtSettlementRecordsExceedPrincipalException implements Exception {
  const DebtSettlementRecordsExceedPrincipalException({
    required this.debtId,
    required this.principalMinorUnits,
    required this.settledMinorUnits,
  });

  final String debtId;
  final int principalMinorUnits;
  final int settledMinorUnits;

  @override
  String toString() =>
      'Debt $debtId has settlements totaling $settledMinorUnits above principal $principalMinorUnits.';
}

/// Read/query boundary for debt exposure and settlement-derived balances.
class DebtQueryService {
  const DebtQueryService({
    required DebtRepository debtRepository,
    required DebtSettlementRepository settlementRepository,
  })  : _debtRepository = debtRepository,
        _settlementRepository = settlementRepository;

  final DebtRepository _debtRepository;
  final DebtSettlementRepository _settlementRepository;

  Future<Debt?> getById(String debtId) =>
      _debtRepository.getById(debtId.trim());

  Future<List<Debt>> activeDebts() async {
    final debts = await _debtRepository.list();
    return List.unmodifiable(
      debts.where((debt) => !debt.isArchived),
    );
  }

  Future<List<DebtSettlement>> settlementsForDebt(String debtId) async {
    final cleanDebtId = debtId.trim();
    if (cleanDebtId.isEmpty) return const [];
    final settlements = await _settlementRepository.list();
    return List.unmodifiable(
      settlements.where((settlement) => settlement.debtId == cleanDebtId),
    );
  }

  Future<int> settledMinorUnits(String debtId) async {
    final debt = await getById(debtId);
    if (debt == null) return 0;
    final settlements = await settlementsForDebt(debt.id);
    return _settledMinorUnitsFor(debt, settlements);
  }

  Future<int> outstandingMinorUnits(String debtId) async {
    final debt = await getById(debtId);
    if (debt == null) return 0;
    final settled = await settledMinorUnits(debt.id);
    if (settled > debt.principalMinorUnits) {
      throw DebtSettlementRecordsExceedPrincipalException(
        debtId: debt.id,
        principalMinorUnits: debt.principalMinorUnits,
        settledMinorUnits: settled,
      );
    }
    return debt.principalMinorUnits - settled;
  }

  Future<bool> isSettled(String debtId) async {
    final debt = await getById(debtId);
    if (debt == null) return false;
    return await outstandingMinorUnits(debt.id) == 0;
  }

  int _settledMinorUnitsFor(
    Debt debt,
    List<DebtSettlement> settlements,
  ) {
    var total = 0;
    for (final settlement in settlements) {
      if (settlement.currencyCode != debt.currencyCode) {
        throw DebtSettlementRecordCurrencyMismatchException(
          debtId: debt.id,
          debtCurrency: debt.currencyCode,
          settlementCurrency: settlement.currencyCode,
        );
      }
      total += settlement.amountMinorUnits;
    }
    return total;
  }
}
