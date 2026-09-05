import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/financial_category.dart';

/// Local-first persistence adapter for financial categories.
class LocalFinancialCategoryRepository implements FinancialCategoryRepository {
  static const String storageKey = 'nus.finance.categories.v1';

  LocalFinancialCategoryRepository(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<FinancialCategory?> getById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    final categories = await list();
    for (final category in categories) {
      if (category.id == cleanId) return category;
    }
    return null;
  }

  @override
  Future<List<FinancialCategory>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const <FinancialCategory>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const <FinancialCategory>[];
    }
    if (decoded is! List<dynamic>) return const <FinancialCategory>[];

    final categories = <FinancialCategory>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        categories.add(FinancialCategory.fromJson(item));
      } on FormatException {
        // One malformed record must not invalidate healthy records.
      }
    }

    categories.sort((a, b) {
      final direction = a.direction.name.compareTo(b.direction.name);
      if (direction != 0) return direction;
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (name != 0) return name;
      return a.id.compareTo(b.id);
    });
    return List<FinancialCategory>.unmodifiable(categories);
  }

  @override
  Future<void> save(FinancialCategory entity) async {
    final raw = _preferences.getString(storageKey);
    final records = _decodeForWrite(raw);
    final next = <Map<String, dynamic>>[];
    var replaced = false;

    for (final record in records) {
      final recordId = record['id'];
      if (recordId == entity.id) {
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
    final category = await getById(id);
    if (category == null) return;
    await archiveById(category.id);
  }

  @override
  Future<void> archiveById(String id) async {
    final category = await getById(id);
    if (category == null) return;
    await save(category.archive());
  }

  List<Map<String, dynamic>> _decodeForWrite(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw StateError('Financial category storage is malformed.');
    }
    if (decoded is! List<dynamic>) {
      throw StateError('Financial category storage root must be a list.');
    }

    final records = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) records.add(item);
    }
    return records;
  }
}
