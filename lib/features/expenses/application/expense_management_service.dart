import '../domain/expense.dart';
import '../domain/id_generator.dart';
import '../domain/recurring_expense_definition.dart';

class ExpenseManagementService {
  const ExpenseManagementService({required ExpenseRepository expenseRepository, required RecurringExpenseRepository recurringRepository}) : _expenses = expenseRepository, _recurring = recurringRepository;
  final ExpenseRepository _expenses;
  final RecurringExpenseRepository _recurring;

  Future<List<Expense>> listExpenses() => _expenses.list();
  Future<Expense?> getExpense(String id) => _expenses.getById(id);

  Future<Expense> createExpense(Expense expense) async {
    final actual = _looksLikeUuid(expense.id) ? expense : Expense(
      id: newEntityId(), userId: expense.userId, amount: expense.amount, date: expense.date,
      category: expense.category, categoryCode: expense.categoryCode, expenseType: expense.expenseType,
      merchant: expense.merchant, description: expense.description, paymentMethod: expense.paymentMethod,
      recurringDefinitionId: expense.recurringDefinitionId, obligationId: expense.obligationId,
      createdAt: expense.createdAt, updatedAt: DateTime.now().toUtc(),
    );
    await _expenses.save(actual);
    return actual;
  }

  Future<Expense> updateExpense(Expense expense) async {
    if (expense.id.trim().isEmpty) throw ArgumentError.value(expense.id, 'id', 'Expense ID is required.');
    await _expenses.save(expense.copyWith(updatedAt: DateTime.now().toUtc()));
    return (await _expenses.getById(expense.id)) ?? expense;
  }

  Future<void> deleteExpense(String id) => _expenses.deleteById(id);
  Future<List<RecurringExpenseDefinition>> listRecurring() => _recurring.list();

  Future<RecurringExpenseDefinition> createRecurring(RecurringExpenseDefinition definition) async {
    final actual = _looksLikeUuid(definition.id) ? definition : RecurringExpenseDefinition(
      id: newEntityId(), userId: definition.userId, name: definition.name, amount: definition.amount,
      categoryCode: definition.categoryCode, frequency: definition.frequency, enabled: definition.enabled,
      startDate: definition.startDate, endDate: definition.endDate, createdAt: definition.createdAt, updatedAt: DateTime.now().toUtc(),
    );
    await _recurring.save(actual);
    return actual;
  }

  Future<RecurringExpenseDefinition> updateRecurring(RecurringExpenseDefinition definition) async {
    await _recurring.save(definition.copyWith());
    return (await _recurring.getById(definition.id)) ?? definition;
  }

  Future<void> deleteRecurring(String id) => _recurring.deleteById(id);
  Future<RecurringExpenseDefinition> setRecurringEnabled(String userId, String id, bool enabled) => _recurring.setEnabled(userId, id, enabled);

  Future<int> monthlyActualTotal({required int year, required int month, required String currencyCode}) async {
    final currency = currencyCode.trim().toUpperCase();
    return (await _expenses.list()).where((e) => e.date.year == year && e.date.month == month && e.amount.currencyCode == currency).fold<int>(0, (sum, e) => sum + e.amount.minorUnits);
  }

  Future<Map<String, int>> monthlyActualByCategory({required int year, required int month, required String currencyCode}) async {
    final currency = currencyCode.trim().toUpperCase();
    final totals = <String, int>{};
    for (final e in await _expenses.list()) { if (e.date.year != year || e.date.month != month || e.amount.currencyCode != currency) continue; final category = e.categoryCode ?? 'other'; totals[category] = (totals[category] ?? 0) + e.amount.minorUnits; }
    final keys = totals.keys.toList()..sort();
    return <String, int>{for (final key in keys) key: totals[key]!};
  }

  Future<int> monthlyExpectedRecurringTotal({required int year, required int month, required String currencyCode}) async {
    final currency = currencyCode.trim().toUpperCase();
    return (await _recurring.list()).where((d) => d.amount.currencyCode == currency && d.appliesToMonth(year, month)).fold<int>(0, (sum, d) => sum + d.normalizedMonthlyAmount);
  }

  bool _looksLikeUuid(String id) => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(id);
}
