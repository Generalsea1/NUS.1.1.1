import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account.dart';

/// SharedPreferences-backed local repository for Finance Account aggregates.
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'nus.finance.accounts.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<Account?> getById(String id) async {
    final accounts = await list();
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Future<List<Account>> list() => _read(throwOnMalformedRoot: false);

  @override
  Future<void> save(Account entity) async {
    final accounts = await _read(throwOnMalformedRoot: true);
    accounts.removeWhere((account) => account.id == entity.id);
    accounts.add(entity);
    _sort(accounts);
    await _write(accounts);
  }

  /// Archive instead of physically deleting an account so future financial
  /// history can retain its stable account identity.
  @override
  Future<void> deleteById(String id) => archiveById(id);

  @override
  Future<void> archiveById(String id) async {
    final accounts = await _read(throwOnMalformedRoot: true);
    final index = accounts.indexWhere((account) => account.id == id);
    if (index == -1) return;
    accounts[index] = accounts[index].archive();
    _sort(accounts);
    await _write(accounts);
  }

  Future<List<Account>> _read({required bool throwOnMalformedRoot}) async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <Account>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      if (throwOnMalformedRoot) {
        throw const FormatException(
          'Account storage contains malformed JSON.',
        );
      }
      return <Account>[];
    }

    if (decoded is! List) {
      if (throwOnMalformedRoot) {
        throw const FormatException(
          'Account storage root must be a JSON array.',
        );
      }
      return <Account>[];
    }

    final accounts = <Account>[];
    final seenIds = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final account = Account.fromJson(Map<String, dynamic>.from(entry));
        if (!seenIds.add(account.id)) continue;
        accounts.add(account);
      } on Object {
        // Isolate one malformed record so valid accounts remain usable.
      }
    }

    _sort(accounts);
    return accounts;
  }

  Future<void> _write(List<Account> accounts) async {
    final prefs = await _prefs;
    final payload = jsonEncode(
      accounts.map((account) => account.toJson()).toList(growable: false),
    );
    final written = await prefs.setString(storageKey, payload);
    if (!written) {
      throw StateError(
        'Account persistence was not accepted by SharedPreferences.',
      );
    }
  }

  static void _sort(List<Account> accounts) {
    accounts.sort((a, b) => a.id.compareTo(b.id));
  }
}
