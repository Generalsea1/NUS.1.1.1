import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/expense.dart';

/// SharedPreferences-backed local repository for Expense aggregates.
class LocalExpenseRepository implements ExpenseRepository {
  LocalExpenseRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'nus.expenses.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<Expense?> getById(String id) async {
    final expenses = await list();
    for (final expense in expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<List<Expense>> list() => _read(throwOnMalformedRoot: false);

  @override
  Future<void> save(Expense entity) async {
    final expenses = await _read(throwOnMalformedRoot: true);
    expenses.removeWhere((expense) => expense.id == entity.id);
    expenses.add(entity);
    _sort(expenses);
    await _write(expenses);
  }

  @override
  Future<void> deleteById(String id) async {
    final expenses = await _read(throwOnMalformedRoot: true);
    expenses.removeWhere((expense) => expense.id == id);
    _sort(expenses);
    await _write(expenses);
  }

  Future<List<Expense>> _read({required bool throwOnMalformedRoot}) async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <Expense>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      if (throwOnMalformedRoot) {
        throw const FormatException('Expense storage contains malformed JSON.');
      }
      return <Expense>[];
    }

    if (decoded is! List) {
      if (throwOnMalformedRoot) {
        throw const FormatException('Expense storage root must be a JSON array.');
      }
      return <Expense>[];
    }

    final expenses = <Expense>[];
    final seenIds = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final expense = Expense.fromJson(Map<String, dynamic>.from(entry));
        if (!seenIds.add(expense.id)) continue;
        expenses.add(expense);
      } on Object {
        // Isolate one malformed record so valid financial data remains usable.
      }
    }

    _sort(expenses);
    return expenses;
  }

  Future<void> _write(List<Expense> expenses) async {
    final prefs = await _prefs;
    final payload = jsonEncode(
      expenses.map((expense) => expense.toJson()).toList(growable: false),
    );
    final written = await prefs.setString(storageKey, payload);
    if (!written) {
      throw StateError('Expense persistence was not accepted by SharedPreferences.');
    }
  }

  static void _sort(List<Expense> expenses) {
    expenses.sort((a, b) {
      final byDate = a.date.toIsoString().compareTo(b.date.toIsoString());
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
  }
}
