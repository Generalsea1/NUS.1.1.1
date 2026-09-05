import '../domain/account.dart';
import '../domain/financial_transaction.dart';
import '../domain/savings_goal.dart';

class SavingsGoalDuplicateIdException implements Exception {
  const SavingsGoalDuplicateIdException(this.id);
  final String id;
}

class SavingsGoalNotFoundException implements Exception {
  const SavingsGoalNotFoundException(this.id);
  final String id;
}

class SavingsGoalAccountNotFoundException implements Exception {
  const SavingsGoalAccountNotFoundException(this.id);
  final String id;
}

class SavingsGoalArchivedAccountException implements Exception {
  const SavingsGoalArchivedAccountException(this.id);
  final String id;
}

class SavingsGoalCurrencyMismatchException implements Exception {
  const SavingsGoalCurrencyMismatchException({
    required this.goalCurrency,
    required this.accountCurrency,
  });
  final String goalCurrency;
  final String accountCurrency;
}

class SavingsGoalTransactionCurrencyMismatchException implements Exception {
  const SavingsGoalTransactionCurrencyMismatchException({
    required this.accountId,
    required this.accountCurrency,
    required this.transactionCurrency,
  });
  final String accountId;
  final String accountCurrency;
  final String transactionCurrency;
}

class SavingsGoalMutationService {
  const SavingsGoalMutationService({
    required SavingsGoalRepository goalRepository,
    required AccountRepository accountRepository,
  })  : _goalRepository = goalRepository,
        _accountRepository = accountRepository;

  final SavingsGoalRepository _goalRepository;
  final AccountRepository _accountRepository;

  Future<void> create(SavingsGoal goal) async {
    final existing = await _goalRepository.getById(goal.id);
    if (existing != null) throw SavingsGoalDuplicateIdException(goal.id);
    await _validateAccount(goal);
    await _goalRepository.save(goal);
  }

  Future<void> update(SavingsGoal goal) async {
    final existing = await _goalRepository.getById(goal.id);
    if (existing == null) throw SavingsGoalNotFoundException(goal.id);
    await _validateAccount(goal);
    await _goalRepository.save(goal);
  }

  Future<void> archive(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw SavingsGoalNotFoundException(id);
    if (await _goalRepository.getById(cleanId) == null) {
      throw SavingsGoalNotFoundException(cleanId);
    }
    await _goalRepository.archiveById(cleanId);
  }

  Future<void> _validateAccount(SavingsGoal goal) async {
    final account = await _accountRepository.getById(goal.progressAccountId);
    if (account == null) {
      throw SavingsGoalAccountNotFoundException(goal.progressAccountId);
    }
    if (account.currencyCode != goal.currencyCode) {
      throw SavingsGoalCurrencyMismatchException(
        goalCurrency: goal.currencyCode,
        accountCurrency: account.currencyCode,
      );
    }
  }
}

class SavingsGoalProgress {
  const SavingsGoalProgress({
    required this.goalId,
    required this.targetMinorUnits,
    required this.progressMinorUnits,
    required this.remainingMinorUnits,
    required this.isReached,
  });

  final String goalId;
  final int targetMinorUnits;
  final int progressMinorUnits;
  final int remainingMinorUnits;
  final bool isReached;
}

/// Query boundary. Progress is derived from the ledger and is never persisted
/// as mutable state on SavingsGoal.
class SavingsGoalQueryService {
  const SavingsGoalQueryService({
    required SavingsGoalRepository goalRepository,
    required AccountRepository accountRepository,
    required FinancialTransactionRepository transactionRepository,
  })  : _goalRepository = goalRepository,
        _accountRepository = accountRepository,
        _transactionRepository = transactionRepository;

  final SavingsGoalRepository _goalRepository;
  final AccountRepository _accountRepository;
  final FinancialTransactionRepository _transactionRepository;

  Future<SavingsGoal?> getById(String id) => _goalRepository.getById(id.trim());

  Future<List<SavingsGoal>> activeGoals() async => List.unmodifiable(
        (await _goalRepository.list()).where((goal) => !goal.isArchived),
      );

  Future<SavingsGoalProgress> progressFor(String goalId) async {
    final goal = await getById(goalId);
    if (goal == null) throw SavingsGoalNotFoundException(goalId.trim());

    final account = await _accountRepository.getById(goal.progressAccountId);
    if (account == null) {
      throw SavingsGoalAccountNotFoundException(goal.progressAccountId);
    }
    if (account.currencyCode != goal.currencyCode) {
      throw SavingsGoalCurrencyMismatchException(
        goalCurrency: goal.currencyCode,
        accountCurrency: account.currencyCode,
      );
    }

    var progress = 0;
    final transactions = await _transactionRepository.list();
    for (final transaction in transactions) {
      if (transaction.accountId != account.id) continue;
      if (transaction.currencyCode != account.currencyCode) {
        throw SavingsGoalTransactionCurrencyMismatchException(
          accountId: account.id,
          accountCurrency: account.currencyCode,
          transactionCurrency: transaction.currencyCode,
        );
      }
      progress += transaction.amountMinorUnits;
    }

    // A negative net movement cannot represent negative goal progress.
    final normalizedProgress = progress < 0 ? 0 : progress;
    final remaining = goal.targetMinorUnits - normalizedProgress;
    return SavingsGoalProgress(
      goalId: goal.id,
      targetMinorUnits: goal.targetMinorUnits,
      progressMinorUnits: normalizedProgress,
      remainingMinorUnits: remaining > 0 ? remaining : 0,
      isReached: normalizedProgress >= goal.targetMinorUnits,
    );
  }
}
