import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/financial_transaction.dart';

/// SharedPreferences-backed local repository for Finance transactions.
class LocalFinancialTransactionRepository
    implements FinancialTransactionRepository {
  LocalFinancialTransactionRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'nus.finance.transactions.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<FinancialTransaction?> getById(String id) async {
    final transactions = await list();
    for (final transaction in transactions) {
      if (transaction.id == id) return transaction;
    }
    return null;
  }

  @override
  Future<List<FinancialTransaction>> list() =>
      _read(throwOnMalformedRoot: false);

  @override
  Future<void> save(FinancialTransaction entity) async {
    final transactions = await _read(throwOnMalformedRoot: true);
    transactions.removeWhere((transaction) => transaction.id == entity.id);
    transactions.add(entity);
    _sort(transactions);
    await _write(transactions);
  }

  @override
  Future<void> deleteById(String id) async {
    final transactions = await _read(throwOnMalformedRoot: true);
    transactions.removeWhere((transaction) => transaction.id == id);
    _sort(transactions);
    await _write(transactions);
  }

  Future<List<FinancialTransaction>> _read({
    required bool throwOnMalformedRoot,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <FinancialTransaction>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      if (throwOnMalformedRoot) {
        throw const FormatException(
          'Financial transaction storage contains malformed JSON.',
        );
      }
      return <FinancialTransaction>[];
    }

    if (decoded is! List) {
      if (throwOnMalformedRoot) {
        throw const FormatException(
          'Financial transaction storage root must be a JSON array.',
        );
      }
      return <FinancialTransaction>[];
    }

    final transactions = <FinancialTransaction>[];
    final seenIds = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final transaction = FinancialTransaction.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (!seenIds.add(transaction.id)) continue;
        transactions.add(transaction);
      } on Object {
        // Isolate one malformed record so valid financial history remains usable.
      }
    }

    _sort(transactions);
    return transactions;
  }

  Future<void> _write(List<FinancialTransaction> transactions) async {
    final prefs = await _prefs;
    final payload = jsonEncode(
      transactions
          .map((transaction) => transaction.toJson())
          .toList(growable: false),
    );
    final written = await prefs.setString(storageKey, payload);
    if (!written) {
      throw StateError(
        'Financial transaction persistence was not accepted by SharedPreferences.',
      );
    }
  }

  static void _sort(List<FinancialTransaction> transactions) {
    transactions.sort((a, b) {
      final byDate = a.occurredOn.compareTo(b.occurredOn);
      if (byDate != 0) return byDate;
      return a.id.compareTo(b.id);
    });
  }
}
