import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/financial_goal.dart';

abstract class FinancialGoalRepository {
  Future<List<FinancialGoal>> list(String userId);
  Future<FinancialGoal?> getById(String userId, String goalId);
  Future<void> save(String userId, FinancialGoal goal);
  Future<void> deleteById(String userId, String goalId);
}

class LocalFinancialGoalRepository implements FinancialGoalRepository {
  LocalFinancialGoalRepository({SharedPreferences? preferences}) : _preferences = preferences;

  static const storageKey = 'nus.financial_goals.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async => _preferences ?? SharedPreferences.getInstance();

  @override
  Future<List<FinancialGoal>> list(String userId) async {
    final cleanUserId = _requireUserId(userId);
    final prefs = await _prefs;
    final decoded = _decodeList(prefs.getString(storageKey));
    final goals = <FinancialGoal>[];
    final seenKeys = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final goal = FinancialGoal.fromJson(Map<String, dynamic>.from(entry));
        final key = _identityKey(goal.userId, goal.id);
        if (goal.userId != cleanUserId || !seenKeys.add(key)) continue;
        goals.add(goal);
      } on Object {
        // Ignore malformed records so valid goals remain readable.
      }
    }
    goals.sort(_compare);
    return goals;
  }

  @override
  Future<FinancialGoal?> getById(String userId, String goalId) async {
    final cleanId = _requireGoalId(goalId);
    for (final goal in await list(userId)) {
      if (goal.id == cleanId) return goal;
    }
    return null;
  }

  @override
  Future<void> save(String userId, FinancialGoal goal) async {
    final cleanUserId = _requireUserId(userId);
    if (goal.userId != cleanUserId) {
      throw StateError('Financial goal ownership does not match the current user.');
    }
    final prefs = await _prefs;
    final goals = _decodeGoals(prefs.getString(storageKey));
    goals.removeWhere((existing) => existing.userId == cleanUserId && existing.id == goal.id);
    goals.add(goal);
    await _writeAll(goals);
  }

  @override
  Future<void> deleteById(String userId, String goalId) async {
    final cleanUserId = _requireUserId(userId);
    final cleanId = _requireGoalId(goalId);
    final prefs = await _prefs;
    final goals = _decodeGoals(prefs.getString(storageKey));
    goals.removeWhere((goal) => goal.userId == cleanUserId && goal.id == cleanId);
    await _writeAll(goals);
  }

  List<FinancialGoal> _decodeGoals(String? raw) {
    final decoded = _decodeList(raw);
    final goals = <FinancialGoal>[];
    final seenKeys = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final goal = FinancialGoal.fromJson(Map<String, dynamic>.from(entry));
        if (seenKeys.add(_identityKey(goal.userId, goal.id))) goals.add(goal);
      } on Object {
        // Ignore malformed records on rewrite; callers still retain valid goals.
      }
    }
    goals.sort(_compare);
    return goals;
  }

  List<dynamic> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : <dynamic>[];
    } on FormatException {
      return <dynamic>[];
    }
  }

  Future<void> _writeAll(List<FinancialGoal> goals) async {
    final prefs = await _prefs;
    goals.sort(_compare);
    await prefs.setString(storageKey, jsonEncode(goals.map((goal) => goal.toJson()).toList()));
  }

  static int _compare(FinancialGoal a, FinancialGoal b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return byStatus;
    final byUpdated = b.updatedAt.compareTo(a.updatedAt);
    if (byUpdated != 0) return byUpdated;
    final byUser = a.userId.compareTo(b.userId);
    if (byUser != 0) return byUser;
    return a.id.compareTo(b.id);
  }

  static String _identityKey(String userId, String goalId) => '$userId\u0000$goalId';

  static String _requireUserId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) throw StateError('Authenticated user is required.');
    return clean;
  }

  static String _requireGoalId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) throw ArgumentError.value(value, 'goalId', 'Goal ID is required.');
    return clean;
  }
}
