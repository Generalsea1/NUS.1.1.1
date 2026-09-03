import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/medication.dart';

class LocalMedicationRepository implements MedicationRepository {
  LocalMedicationRepository({SharedPreferences? preferences}) : _preferences = preferences;

  static const storageKey = 'nus.medications.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<Medication?> getById(String id) async {
    final medications = await list();
    for (final medication in medications) {
      if (medication.id == id) return medication;
    }
    return null;
  }

  @override
  Future<List<Medication>> list() async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <Medication>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <Medication>[];
    }
    if (decoded is! List) return <Medication>[];

    final medications = <Medication>[];
    final seenIds = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final medication = Medication.fromJson(Map<String, dynamic>.from(entry));
        if (!seenIds.add(medication.id)) continue;
        medications.add(medication);
      } on Object {
        // Ignore one malformed local record rather than losing all medications.
      }
    }

    _sort(medications);
    return medications;
  }

  @override
  Future<void> save(Medication entity) async {
    final errors = MedicationValidator.validate(entity);
    if (errors.isNotEmpty) throw ArgumentError('Invalid medication data.');

    final medications = await list();
    medications.removeWhere((item) => item.id == entity.id);
    medications.add(entity);
    _sort(medications);

    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(medications.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteById(String id) async {
    final medications = await list();
    medications.removeWhere((item) => item.id == id);
    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(medications.map((item) => item.toJson()).toList()),
    );
  }

  static void _sort(List<Medication> medications) {
    medications.sort((a, b) {
      final active = b.isActive ? 1 : 0;
      final otherActive = a.isActive ? 1 : 0;
      if (active != otherActive) return active.compareTo(otherActive);
      final start = a.startDate.compareTo(b.startDate);
      if (start != 0) return start;
      return a.id.compareTo(b.id);
    });
  }
}
