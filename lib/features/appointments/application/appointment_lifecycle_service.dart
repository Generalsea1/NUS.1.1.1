import 'dart:math';

import '../domain/appointment.dart';

/// Application boundary for creating and maintaining local appointments.
///
/// Creation is kept out of the UI and includes a lightweight semantic
/// duplicate guard for retried Quick Add requests.
class AppointmentLifecycleService {
  AppointmentLifecycleService({required AppointmentRepository repository})
      : _repository = repository;

  final AppointmentRepository _repository;
  static final Random _random = Random.secure();

  Future<List<Appointment>> getAll() => _repository.list();

  Future<Appointment> create({
    required String title,
    required DateTime startsAt,
    AppointmentType type = AppointmentType.personal,
    String? doctorName,
    String? specialty,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Appointment title must not be empty.');
    }

    final existing = await _repository.list();
    final duplicate = existing.where((appointment) =>
        appointment.status == AppointmentStatus.upcoming &&
        appointment.type == type &&
        appointment.title.trim().toLowerCase() == cleanTitle.toLowerCase() &&
        appointment.startsAt.isAtSameMomentAs(startsAt));
    if (duplicate.isNotEmpty) return duplicate.first;

    final normalizedDoctorName = doctorName?.trim();
    Appointment appointment;
    do {
      appointment = Appointment(
        id: _newId(),
        title: cleanTitle,
        type: type,
        startsAt: startsAt,
        doctorName: type == AppointmentType.doctor
            ? ((normalizedDoctorName == null || normalizedDoctorName.isEmpty) ? cleanTitle : normalizedDoctorName)
            : (normalizedDoctorName == null || normalizedDoctorName.isEmpty ? null : normalizedDoctorName),
        specialty: specialty?.trim().isEmpty == true ? null : specialty?.trim(),
      );
    } while (existing.any((current) => current.id == appointment.id));

    final errors = AppointmentValidator.validate(appointment);
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid appointment: ${errors.join(', ')}');
    }

    await _repository.save(appointment);
    return appointment;
  }

  Future<void> delete(String appointmentId) => _repository.deleteById(appointmentId);

  Future<Appointment> update(Appointment appointment) async {
    final errors = AppointmentValidator.validate(appointment);
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid appointment: ${errors.join(', ')}');
    }
    await _repository.save(appointment);
    return appointment;
  }

  static String _newId() {
    final first = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    final second = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ap-$first$second';
  }
}