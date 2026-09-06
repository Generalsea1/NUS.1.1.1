import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

enum AppointmentType { personal, doctor, work, government, study, family, travel, phoneCall, custom }

enum AppointmentRecurrence { none, daily, weekly }

enum AppointmentReminder { none, atTime, fiveMinutesBefore, fifteenMinutesBefore, thirtyMinutesBefore, oneHourBefore, oneDayBefore }

enum AppointmentStatus { upcoming, completed, cancelled }

class Appointment implements DomainEntity {
  const Appointment({
    required this.id,
    required this.title,
    this.type = AppointmentType.personal,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.notes,
    this.contactName,
    this.contactPhone,
    this.recurrence = AppointmentRecurrence.none,
    this.reminder = AppointmentReminder.none,
    this.status = AppointmentStatus.upcoming,
    this.doctorName,
    this.specialty,
    this.followUpAt,
  });

  @override
  final String id;
  final String title;
  final AppointmentType type;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? notes;
  final String? contactName;
  final String? contactPhone;
  final AppointmentRecurrence recurrence;
  final AppointmentReminder reminder;
  final AppointmentStatus status;
  final String? doctorName;
  final String? specialty;
  final DateTime? followUpAt;

  bool get isDoctor => type == AppointmentType.doctor;
  bool get isScheduledCall => type == AppointmentType.phoneCall;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt?.toIso8601String(),
        'location': location,
        'notes': notes,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'recurrence': recurrence.name,
        'reminder': reminder.name,
        'status': status.name,
        'doctorName': doctorName,
        'specialty': specialty,
        'followUpAt': followUpAt?.toIso8601String(),
      };

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as String,
        title: json['title'] as String,
        type: _enumByName(AppointmentType.values, json['type'] as String?) ?? AppointmentType.personal,
        startsAt: DateTime.parse(json['startsAt'] as String),
        endsAt: _dateTime(json['endsAt']),
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        contactName: json['contactName'] as String?,
        contactPhone: json['contactPhone'] as String?,
        recurrence: _enumByName(AppointmentRecurrence.values, json['recurrence'] as String?) ?? AppointmentRecurrence.none,
        reminder: _enumByName(AppointmentReminder.values, json['reminder'] as String?) ?? AppointmentReminder.none,
        status: _enumByName(AppointmentStatus.values, json['status'] as String?) ?? AppointmentStatus.upcoming,
        doctorName: json['doctorName'] as String?,
        specialty: json['specialty'] as String?,
        followUpAt: _dateTime(json['followUpAt']),
      );

  Appointment copyWith({
    String? id,
    String? title,
    AppointmentType? type,
    DateTime? startsAt,
    DateTime? endsAt,
    String? location,
    String? notes,
    String? contactName,
    String? contactPhone,
    AppointmentRecurrence? recurrence,
    AppointmentReminder? reminder,
    AppointmentStatus? status,
    String? doctorName,
    String? specialty,
    DateTime? followUpAt,
  }) => Appointment(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        startsAt: startsAt ?? this.startsAt,
        endsAt: endsAt ?? this.endsAt,
        location: location ?? this.location,
        notes: notes ?? this.notes,
        contactName: contactName ?? this.contactName,
        contactPhone: contactPhone ?? this.contactPhone,
        recurrence: recurrence ?? this.recurrence,
        reminder: reminder ?? this.reminder,
        status: status ?? this.status,
        doctorName: doctorName ?? this.doctorName,
        specialty: specialty ?? this.specialty,
        followUpAt: followUpAt ?? this.followUpAt,
      );

  static DateTime? _dateTime(Object? value) => value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class AppointmentValidator {
  const AppointmentValidator._();

  static List<String> validate(Appointment appointment, {DateTime? now}) {
    final errors = <String>[];
    final current = now ?? DateTime.now();
    if (appointment.title.trim().isEmpty) errors.add('title_required');
    if (appointment.id.trim().isEmpty) errors.add('id_required');
    if (appointment.endsAt != null && !appointment.endsAt!.isAfter(appointment.startsAt)) {
      errors.add('end_after_start');
    }
    if (appointment.status == AppointmentStatus.upcoming && !appointment.startsAt.isAfter(current)) {
      errors.add('start_must_be_future');
    }
    if (appointment.recurrence != AppointmentRecurrence.none && appointment.status != AppointmentStatus.upcoming) {
      errors.add('recurrence_requires_upcoming');
    }
    final phone = appointment.contactPhone?.trim() ?? '';
    if (phone.isNotEmpty && !isValidPhone(phone)) errors.add('invalid_phone');
    if (appointment.isScheduledCall) {
      if (appointment.contactName?.trim().isEmpty ?? true) errors.add('call_contact_required');
      if (phone.isEmpty) {
        errors.add('call_phone_required');
      }
    }
    if (appointment.isDoctor && (appointment.doctorName?.trim().isEmpty ?? true)) {
      errors.add('doctor_name_required');
    }
    if (appointment.isDoctor && appointment.followUpAt != null && !appointment.followUpAt!.isAfter(appointment.startsAt)) {
      errors.add('follow_up_after_appointment');
    }
    return errors;
  }

  static bool isValidPhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 25) return false;
    return RegExp(r'^\+?[0-9][0-9 ().\-]{5,23}$').hasMatch(trimmed);
  }

  static String normalizePhone(String value) => value.replaceAll(RegExp(r'[\s().\-]'), '');
}

abstract interface class AppointmentRepository implements DomainRepository<Appointment> {}
