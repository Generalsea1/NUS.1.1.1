import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/subscription.dart';

/// Local-first persistence for recurring financial obligations.
class LocalSubscriptionRepository implements SubscriptionRepository {
  static const storageKey = 'nus.finance.subscriptions.v1';

  const LocalSubscriptionRepository(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<Subscription?> getById(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;
    for (final subscription in await list()) {
      if (subscription.id == clean) return subscription;
    }
    return null;
  }

  @override
  Future<List<Subscription>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List<dynamic>) return const [];

    final subscriptions = <Subscription>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try {
        subscriptions.add(Subscription.fromJson(item));
      } on FormatException {
        // Isolate malformed records instead of failing the collection.
      }
    }
    subscriptions.sort((a, b) {
      final due = a.nextDueAt.compareTo(b.nextDueAt);
      if (due != 0) return due;
      final title = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return title != 0 ? title : a.id.compareTo(b.id);
    });
    return List.unmodifiable(subscriptions);
  }

  @override
  Future<void> save(Subscription entity) async {
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
      throw StateError('Financial subscription storage is malformed.');
    }
    if (decoded is! List<dynamic>) {
      throw StateError('Financial subscription storage root must be a list.');
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) item,
    ];
  }
}
