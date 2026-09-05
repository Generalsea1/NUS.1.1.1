import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/debt_settlement.dart';

/// Local-first persistence for debt settlement records.
class LocalDebtSettlementRepository implements DebtSettlementRepository {
  static const storageKey = 'nus.finance.debt_settlements.v1';

  const LocalDebtSettlementRepository(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<DebtSettlement?> getById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    for (final settlement in await list()) {
      if (settlement.id == clean) return settlement;
    }
    return null;
  }

  @override
  Future<List<DebtSettlement>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List<dynamic>) return const [];

    final settlements = <DebtSettlement>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        settlements.add(DebtSettlement.fromJson(item));
      } on FormatException {
        // Preserve healthy neighboring records.
      }
    }

    settlements.sort((a, b) {
      final settledAt = a.settledAt.compareTo(b.settledAt);
      return settledAt != 0 ? settledAt : a.id.compareTo(b.id);
    });
    return List.unmodifiable(settlements);
  }

  @override
  Future<void> save(DebtSettlement entity) async {
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
    final records = _decodeForWrite(_preferences.getString(storageKey));
    final next = records.where((record) => record['id'] != clean).toList();
    await _preferences.setString(storageKey, jsonEncode(next));
  }

  List<Map<String, dynamic>> _decodeForWrite(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StateError('Debt settlement storage is malformed.');
    }
    if (decoded is! List<dynamic>) {
      throw StateError('Debt settlement storage root must be a list.');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) item,
    ];
  }
}
