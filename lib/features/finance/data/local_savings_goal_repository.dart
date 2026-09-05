import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/savings_goal.dart';

class LocalSavingsGoalRepository implements SavingsGoalRepository {
  static const storageKey = 'nus.finance.savings_goals.v1';
  const LocalSavingsGoalRepository(this._preferences);
  final SharedPreferences _preferences;

  @override
  Future<SavingsGoal?> getById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    for (final goal in await list()) {
      if (goal.id == cleanId) return goal;
    }
    return null;
  }

  @override
  Future<List<SavingsGoal>> list() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    dynamic decoded;
    try { decoded = jsonDecode(raw); } on FormatException { return const []; }
    if (decoded is! List<dynamic>) return const [];
    final goals = <SavingsGoal>[];
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      try { goals.add(SavingsGoal.fromJson(item)); } on FormatException { }
    }
    goals.sort((a, b) {
      final byDate = a.targetDate.compareTo(b.targetDate);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return List.unmodifiable(goals);
  }

  @override
  Future<void> save(SavingsGoal goal) async {
    final raw = _preferences.getString(storageKey);
    List<dynamic> decoded;
    if (raw == null || raw.trim().isEmpty) {
      decoded = <dynamic>[];
    } else {
      final parsed = jsonDecode(raw);
      if (parsed is! List<dynamic>) {
        throw const StateError('Savings goal storage root is malformed.');
      }
      decoded = List<dynamic>.from(parsed);
    }
    final next = <Map<String, dynamic>>[];
    var replaced = false;
    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      if (item['id'] == goal.id) {
        next.add(goal.toJson());
        replaced = true;
      } else {
        next.add(Map<String, dynamic>.from(item));
      }
    }
    if (!replaced) next.add(goal.toJson());
    next.sort((a, b) => (a['id'] as String? ?? '').compareTo(b['id'] as String? ?? ''));
    await _preferences.setString(storageKey, jsonEncode(next));
  }

  @override
  Future<void> archiveById(String id) async {
    final goal = await getById(id);
    if (goal != null) await save(goal.archive());
  }
}
