import '../domain/financial_category.dart';
import '../domain/financial_transaction.dart';
import 'financial_transaction_mutation_service.dart';

/// Controlled application entry point for recording an income transaction.
///
/// Income remains a transaction direction in the ledger. A future first-class
/// Income source aggregate can be added without changing this boundary.
class IncomeCaptureService {
  IncomeCaptureService({
    required FinancialTransactionMutationService transactionMutations,
    required FinancialCategoryRepository categoryRepository,
  })  : _transactionMutations = transactionMutations,
        _categoryRepository = categoryRepository;

  final FinancialTransactionMutationService _transactionMutations;
  final FinancialCategoryRepository _categoryRepository;

  Future<FinancialTransaction> recordIncome({
    required String id,
    required String accountId,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime occurredOn,
    String? categoryId,
    String? counterparty,
    String? note,
    String? externalReference,
  }) async {
    if (amountMinorUnits <= 0) {
      throw ArgumentError.value(
        amountMinorUnits,
        'amountMinorUnits',
        'Income amount must be greater than zero.',
      );
    }

    final cleanCategoryId = categoryId?.trim();
    if (cleanCategoryId != null && cleanCategoryId.isNotEmpty) {
      final category = await _categoryRepository.getById(cleanCategoryId);
      if (category == null) {
        throw StateError('Income category does not exist.');
      }
      if (category.isArchived) {
        throw StateError('Archived income categories cannot be used.');
      }
      if (category.direction != FinancialCategoryDirection.income) {
        throw StateError('An expense category cannot classify income.');
      }
    }

    return _transactionMutations.createTransaction(
      id: id,
      accountId: accountId,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      occurredOn: occurredOn,
      categoryId: cleanCategoryId == null || cleanCategoryId.isEmpty
          ? null
          : cleanCategoryId,
      counterparty: counterparty,
      note: note,
      externalReference: externalReference,
    );
  }
}
