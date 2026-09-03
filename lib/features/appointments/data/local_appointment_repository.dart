import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appointment.dart';

class LocalAppointmentRepository implements AppointmentRepository {
  LocalAppointmentRepository({SharedPreferences? preferences}) : _preferences = preferences;

  static const storageKey = 'nus.appointments.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<Appointment?> getById(String id) async {
    final appointments = await list();
    for (final appointment in appointments) {
      if (appointment.id == id) return appointment;
    }
    return null;
  }

  @override
  Future<List<Appointment>> list() async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <Appointment>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <Appointment>[];

    final appointments = <Appointment>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        appointments.add(
          Appointment.fromJson(Map<String, dynamic>.from(entry)),
        );
      } on Object {
        // Ignore one malformed local record rather than losing all appointments.
      }
    }
    appointments.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return appointments;
  }

  @override
  Future<void> save(Appointment entity) async {
    if (AppointmentValidator.validate(entity).where((e) => e != 'start_must_be_future').isNotEmpty) {
      throw ArgumentError('Invalid appointment data.');
    }

    final appointments = await list();
    final index = appointments.indexWhere((item) => item.id == entity.id);
    if (index == -1) {
      appointments.add(entity);
    } else {
      appointments[index] = entity;
    }
    appointments.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(appointments.map((item) => item.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteById(String id) async {
    final appointments = await list();
    appointments.removeWhere((item) => item.id == id);
    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(appointments.map((item) => item.toJson()).toList()),
    );
  }
}
