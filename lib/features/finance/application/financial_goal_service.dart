import '../../expenses/domain/id_generator.dart';
import '../../expenses/domain/money.dart';
import '../domain/financial_goal.dart';
import '../data/local_financial_goal_repository.dart';

class FinancialGoalService {
  const FinancialGoalService({required FinancialGoalRepository repository})
      : _repository = repository;

  final FinancialGoalRepository _repository;

  Future<List<FinancialGoal>> list(String userId) => _repository.list(userId);

  Future<FinancialGoal?> get(String userId, String goalId) =>
      _repository.getById(userId, goalId);

  Future<FinancialGoal> create({
    required String userId,
    required String name,
    required int targetMinorUnits,
    required String targetCurrencyCode,
    DateTime? targetDate,
    int? currentMinorUnits,
  }) async {
    final cleanUserId = _requireUserId(userId);
    final targetCurrency = targetCurrencyCode.trim().toUpperCase();
    final target = Money(
      minorUnits: targetMinorUnits,
      currencyCode: targetCurrency,
    );
    final current = currentMinorUnits == null
        ? null
        : Money(minorUnits: currentMinorUnits, currencyCode: target.currencyCode);
    final now = DateTime.now().toUtc();
    final goal = FinancialGoal(
      id: newEntityId(),
      userId: cleanUserId,
      name: name,
      targetAmount: target,
      targetDate: targetDate,
      currentAmount: current,
      createdAt: now,
      updatedAt: now,
    );
    await _repository.save(cleanUserId, goal);
    return goal;
  }

  Future<FinancialGoal> update(FinancialGoal goal) async {
    final cleanUserId = _requireUserId(goal.userId);
    final existing = await _repository.getById(cleanUserId, goal.id);
    if (existing == null) {
      throw StateError('Financial goal was not found or does not belong to this user.');
    }
    final updated = goal.copyWith();
    await _repository.save(cleanUserId, updated);
    return updated;
  }

  Future<FinancialGoal> setCurrentAmount({
    required String userId,
    required String goalId,
    required int? currentMinorUnits,
  }) async {
    final goal = await _requireOwned(userId, goalId);
    final current = currentMinorUnits == null
        ? null
        : Money(
            minorUnits: currentMinorUnits,
            currencyCode: goal.targetAmount.currencyCode,
          );
    return update(goal.copyWith(currentAmount: current));
  }

  Future<FinancialGoal> pause(String userId, String goalId) async {
    final goal = await _requireOwned(userId, goalId);
    if (goal.isCompleted) return goal;
    return update(goal.copyWith(status: FinancialGoalStatus.paused));
  }

  Future<FinancialGoal> resume(String userId, String goalId) async {
    final goal = await _requireOwned(userId, goalId);
    if (goal.isCompleted) return goal;
    return update(goal.copyWith(status: FinancialGoalStatus.active));
  }

  Future<void> delete(String userId, String goalId) async {
    final cleanUserId = _requireUserId(userId);
    final existing = await _repository.getById(cleanUserId, goalId);
    if (existing == null) return;
    await _repository.deleteById(cleanUserId, goalId);
  }

  Future<FinancialGoal> _requireOwned(String userId, String goalId) async {
    final cleanUserId = _requireUserId(userId);
    final goal = await _repository.getById(cleanUserId, goalId);
    if (goal == null) {
      throw StateError('Financial goal was not found or does not belong to this user.');
    }
    return goal;
  }

  static String _requireUserId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) throw StateError('Authenticated user is required.');
    return clean;
  }
}
