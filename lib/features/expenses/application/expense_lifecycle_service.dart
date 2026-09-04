import '../domain/expense.dart';

/// Application boundary for Expense lifecycle orchestration.
///
/// The service depends only on the [ExpenseRepository] abstraction and does
/// not know about persistence details or Flutter UI concerns.
class ExpenseLifecycleService {
  const ExpenseLifecycleService({required ExpenseRepository repository})
      : _repository = repository;

  final ExpenseRepository _repository;

  Future<Expense> create(Expense expense) async {
    await _repository.save(expense);
    return expense;
  }

  Future<Expense> update(Expense expense) async {
    _validateId(expense.id);
    await _repository.save(expense);
    return expense;
  }

  Future<void> deleteById(String id) async {
    _validateId(id);
    await _repository.deleteById(id);
  }

  Future<Expense?> getById(String id) async {
    _validateId(id);
    return _repository.getById(id);
  }

  Future<List<Expense>> list() async {
    final expenses = await _repository.list();
    return List<Expense>.unmodifiable(expenses);
  }

  static void _validateId(String id) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Expense ID must not be empty.');
    }
  }
}
