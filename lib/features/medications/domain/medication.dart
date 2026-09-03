import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

enum DosageUnit {
  tablet,
  capsule,
  ml,
  drop,
  puff,
  injection,
  custom,
}

extension DosageUnitCodec on DosageUnit {
  String get value => switch (this) {
        DosageUnit.tablet => 'tablet',
        DosageUnit.capsule => 'capsule',
        DosageUnit.ml => 'ml',
        DosageUnit.drop => 'drop',
        DosageUnit.puff => 'puff',
        DosageUnit.injection => 'injection',
        DosageUnit.custom => 'custom',
      };

  static DosageUnit fromValue(Object? value) => switch (value) {
        'tablet' => DosageUnit.tablet,
        'capsule' => DosageUnit.capsule,
        'ml' => DosageUnit.ml,
        'drop' => DosageUnit.drop,
        'puff' => DosageUnit.puff,
        'injection' => DosageUnit.injection,
        'custom' => DosageUnit.custom,
        _ => throw const FormatException('Invalid dosage unit.'),
      };
}

class Dosage {
  const Dosage({
    required this.amount,
    required this.unit,
    this.customUnit,
  });

  factory Dosage.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    if (amount is! String) throw const FormatException('Invalid dosage amount.');
    return Dosage(
      amount: amount,
      unit: DosageUnitCodec.fromValue(json['unit']),
      customUnit: json['customUnit'] as String?,
    );
  }

  final String amount;
  final DosageUnit unit;
  final String? customUnit;

  List<String> validate() {
    final errors = <String>[];
    if (amount.trim().isEmpty) errors.add('amount_required');
    if (unit == DosageUnit.custom) {
      if (customUnit == null || customUnit!.trim().isEmpty) {
        errors.add('custom_unit_required');
      }
    } else if (customUnit != null) {
      errors.add('custom_unit_not_allowed');
    }
    return errors;
  }

  Dosage copyWith({
    String? amount,
    DosageUnit? unit,
    String? customUnit,
    bool clearCustomUnit = false,
  }) =>
      Dosage(
        amount: amount ?? this.amount,
        unit: unit ?? this.unit,
        customUnit: clearCustomUnit ? null : (customUnit ?? this.customUnit),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'amount': amount,
        'unit': unit.value,
        'customUnit': customUnit,
      };
}

enum MedicationFrequency {
  daily,
  selectedWeekdays,
}

extension MedicationFrequencyCodec on MedicationFrequency {
  String get value => switch (this) {
        MedicationFrequency.daily => 'daily',
        MedicationFrequency.selectedWeekdays => 'selected_weekdays',
      };

  static MedicationFrequency fromValue(Object? value) => switch (value) {
        'daily' => MedicationFrequency.daily,
        'selected_weekdays' => MedicationFrequency.selectedWeekdays,
        _ => throw const FormatException('Invalid medication frequency.'),
      };
}

enum MedicationReminder {
  none,
  atTime,
  fiveMinutesBefore,
  fifteenMinutesBefore,
  thirtyMinutesBefore,
  sixtyMinutesBefore,
  oneDayBefore,
}

extension MedicationReminderCodec on MedicationReminder {
  String get value => switch (this) {
        MedicationReminder.none => 'none',
        MedicationReminder.atTime => 'at_time',
        MedicationReminder.fiveMinutesBefore => 'five_minutes_before',
        MedicationReminder.fifteenMinutesBefore => 'fifteen_minutes_before',
        MedicationReminder.thirtyMinutesBefore => 'thirty_minutes_before',
        MedicationReminder.sixtyMinutesBefore => 'sixty_minutes_before',
        MedicationReminder.oneDayBefore => 'one_day_before',
      };

  static MedicationReminder fromValue(Object? value) => switch (value) {
        'none' => MedicationReminder.none,
        'at_time' => MedicationReminder.atTime,
        'five_minutes_before' => MedicationReminder.fiveMinutesBefore,
        'fifteen_minutes_before' => MedicationReminder.fifteenMinutesBefore,
        'thirty_minutes_before' => MedicationReminder.thirtyMinutesBefore,
        'sixty_minutes_before' => MedicationReminder.sixtyMinutesBefore,
        'one_day_before' => MedicationReminder.oneDayBefore,
        _ => throw const FormatException('Invalid medication reminder.'),
      };
}

class MedicationSchedule {
  MedicationSchedule({
    required this.id,
    required this.minutesSinceMidnight,
    required this.frequency,
    List<int> selectedWeekdays = const <int>[],
    this.reminder = MedicationReminder.none,
  }) : selectedWeekdays = List.unmodifiable(selectedWeekdays);

  factory MedicationSchedule.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final minutes = json['minutesSinceMidnight'];
    final weekdays = json['selectedWeekdays'];
    if (id is! String || minutes is! int || weekdays is! List) {
      throw const FormatException('Invalid medication schedule.');
    }
    return MedicationSchedule(
      id: id,
      minutesSinceMidnight: minutes,
      frequency: MedicationFrequencyCodec.fromValue(json['frequency']),
      selectedWeekdays: weekdays.map((value) {
        if (value is! int) throw const FormatException('Invalid weekday.');
        return value;
      }).toList(growable: false),
      reminder: MedicationReminderCodec.fromValue(json['reminder']),
    );
  }

  final String id;
  final int minutesSinceMidnight;
  final MedicationFrequency frequency;
  final List<int> selectedWeekdays;
  final MedicationReminder reminder;

  List<String> validate() {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('schedule_id_required');
    if (minutesSinceMidnight < 0 || minutesSinceMidnight > 1439) {
      errors.add('schedule_time_invalid');
    }
    final normalizedWeekdays = [...selectedWeekdays]..sort();
    final validWeekdays = normalizedWeekdays.every((day) => day >= 1 && day <= 7);
    final uniqueWeekdays = normalizedWeekdays.toSet().length == normalizedWeekdays.length;
    if (!validWeekdays) errors.add('weekday_invalid');
    if (!uniqueWeekdays) errors.add('weekday_duplicate');
    if (frequency == MedicationFrequency.selectedWeekdays && selectedWeekdays.isEmpty) {
      errors.add('weekday_required');
    }
    if (frequency == MedicationFrequency.daily && selectedWeekdays.isNotEmpty) {
      errors.add('weekday_not_allowed_for_daily');
    }
    return errors;
  }

  MedicationSchedule copyWith({
    String? id,
    int? minutesSinceMidnight,
    MedicationFrequency? frequency,
    List<int>? selectedWeekdays,
    MedicationReminder? reminder,
  }) =>
      MedicationSchedule(
        id: id ?? this.id,
        minutesSinceMidnight: minutesSinceMidnight ?? this.minutesSinceMidnight,
        frequency: frequency ?? this.frequency,
        selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
        reminder: reminder ?? this.reminder,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'minutesSinceMidnight': minutesSinceMidnight,
        'frequency': frequency.value,
        'selectedWeekdays': [...selectedWeekdays]..sort(),
        'reminder': reminder.value,
      };
}

class Medication implements DomainEntity {
  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    this.instructions,
    this.notes,
    required DateTime startDate,
    DateTime? endDate,
    this.isActive = true,
    required List<MedicationSchedule> schedules,
  })  : startDate = _dateOnly(startDate),
        endDate = endDate == null ? null : _dateOnly(endDate),
        schedules = List.unmodifiable(schedules);

  factory Medication.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final dosage = json['dosage'];
    final schedules = json['schedules'];
    if (id is! String || name is! String || dosage is! Map || schedules is! List) {
      throw const FormatException('Invalid medication record.');
    }
    return Medication(
      id: id,
      name: name,
      dosage: Dosage.fromJson(Map<String, dynamic>.from(dosage)),
      instructions: json['instructions'] as String?,
      notes: json['notes'] as String?,
      startDate: _parseDate(json['startDate']),
      endDate: json['endDate'] == null ? null : _parseDate(json['endDate']),
      isActive: json['isActive'] as bool? ?? true,
      schedules: schedules.map((entry) {
        if (entry is! Map) throw const FormatException('Invalid medication schedule record.');
        return MedicationSchedule.fromJson(Map<String, dynamic>.from(entry));
      }).toList(growable: false),
    );
  }

  @override
  final String id;
  final String name;
  final Dosage dosage;
  final String? instructions;
  final String? notes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final List<MedicationSchedule> schedules;

  Medication copyWith({
    String? id,
    String? name,
    Dosage? dosage,
    String? instructions,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    List<MedicationSchedule>? schedules,
    bool clearInstructions = false,
    bool clearNotes = false,
    bool clearEndDate = false,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        instructions: clearInstructions ? null : (instructions ?? this.instructions),
        notes: clearNotes ? null : (notes ?? this.notes),
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        isActive: isActive ?? this.isActive,
        schedules: schedules ?? this.schedules,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'dosage': dosage.toJson(),
        'instructions': instructions,
        'notes': notes,
        'startDate': _formatDate(startDate),
        'endDate': endDate == null ? null : _formatDate(endDate!),
        'isActive': isActive,
        'schedules': (schedules.map((schedule) => schedule.toJson()).toList())
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
      };
}

abstract interface class MedicationRepository
    implements DomainRepository<Medication> {}

class MedicationValidator {
  static List<String> validate(Medication medication) {
    final errors = <String>[];
    if (medication.id.trim().isEmpty) errors.add('id_required');
    if (medication.name.trim().isEmpty) errors.add('name_required');
    errors.addAll(medication.dosage.validate());
    if (medication.schedules.isEmpty) errors.add('schedules_required');
    final scheduleIds = <String>{};
    final definitions = <String>{};
    for (final schedule in medication.schedules) {
      errors.addAll(schedule.validate());
      if (!scheduleIds.add(schedule.id)) errors.add('schedule_id_duplicate');
      final definition = scheduleSignature(schedule);
      if (!definitions.add(definition)) errors.add('schedule_duplicate');
    }
    if (medication.endDate != null && medication.endDate!.isBefore(medication.startDate)) {
      errors.add('end_date_before_start_date');
    }
    return errors.toSet().toList(growable: false);
  }

  static String scheduleSignature(MedicationSchedule schedule) {
    final weekdays = [...schedule.selectedWeekdays]..sort();
    return '${schedule.minutesSinceMidnight}|${schedule.frequency.value}|${weekdays.join(',')}|${schedule.reminder.value}';
  }
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _parseDate(Object? value) {
  if (value is! String) throw const FormatException('Invalid date.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Invalid date.');
  return _dateOnly(parsed);
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
