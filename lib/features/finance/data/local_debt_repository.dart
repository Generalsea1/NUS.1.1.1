import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/debt.dart';

/// Local-first persistence for debt aggregates.
class LocalDebtRepository implements DebtRepository {
  static const storageKey = 'nus.finance.debts.v1';

  const LocalDebtRepository(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<Debt?> getById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    for (final debt in await list()) {
      if (debt.id == clean) return debt;
    }
    return null;
  }

  @override
  Future<List<Debt>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List<dynamic>) return const [];

    final debts = <Debt>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        debts.add(Debt.fromJson(item));
      } on FormatException {
        // Preserve healthy neighboring records.
      }
    }

    debts.sort((a, b) {
      if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
      final dueA = a.dueAt;
      final dueB = b.dueAt;
      if (dueA == null && dueB != null) return 1;
      if (dueA != null && dueB == null) return -1;
      if (dueA != null && dueB != null) {
        final due = dueA.compareTo(dueB);
        if (due != 0) return due;
      }
      final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return title != 0 ? title : a.id.compareTo(b.id);
    });
    return List.unmodifiable(debts);
  }

  @override
  Future<void> save(Debt entity) async {
    final records = _decodeForWrite(_preferences.getString(storageKey));
    final next = <Map<String, dynamic>>[];
    var replaced = false;
    for (final record in records) {
      if (record['id'] == entity.id) {
        if (!replaced) {
          next.add(entity.toJson());
          replaced = true;
        }
      } else {
        next.add(record);
      }
    }
    if (!replaced) next.add(entity.toJson());
    await _preferences.setString(storageKey, jsonEncode(next));
  }

  @override
  Future<void> deleteById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return;
    final current = await getById(clean);
    if (current == null || current.isArchived) return;
    await save(current.archive());
  }

  @override
  Future<void> archiveById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return;
    final current = await getById(clean);
    if (current == null || current.isArchived) return;
    await save(current.archive());
  }

  List<Map<String, dynamic>> _decodeForWrite(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StateError('Financial debt storage is malformed.');
    }
    if (decoded is! List<dynamic>) {
      throw StateError('Financial debt storage root must be a list.');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) item,
    ];
  }
}
