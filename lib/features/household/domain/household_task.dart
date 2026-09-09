class HouseholdTask {
  factory HouseholdTask({
    required String id,
    required String householdId,
    required String createdBy,
    required String title,
    required bool completed,
    DateTime? dueAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final cleanId = id.trim();
    final cleanHouseholdId = householdId.trim();
    final cleanCreatedBy = createdBy.trim();
    final cleanTitle = title.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Task ID is required.');
    if (cleanHouseholdId.isEmpty) throw ArgumentError.value(householdId, 'householdId', 'Household ID is required.');
    if (cleanCreatedBy.isEmpty) throw ArgumentError.value(createdBy, 'createdBy', 'Task creator is required.');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Task title is required.');
    if (cleanTitle.length > 300) throw ArgumentError.value(title, 'title', 'Task title cannot exceed 300 characters.');
    if (!completed && completedAt != null) {
      throw ArgumentError.value(completedAt, 'completedAt', 'Incomplete task cannot have completedAt.');
    }
    return HouseholdTask._(
      id: cleanId,
      householdId: cleanHouseholdId,
      createdBy: cleanCreatedBy,
      title: cleanTitle,
      completed: completed,
      dueAt: dueAt?.toUtc(),
      completedAt: completedAt?.toUtc(),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      updatedAt: (updatedAt ?? DateTime.now().toUtc()).toUtc(),
    );
  }

  const HouseholdTask._({
    required this.id,
    required this.householdId,
    required this.createdBy,
    required this.title,
    required this.completed,
    required this.dueAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String householdId;
  final String createdBy;
  final String title;
  final bool completed;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  HouseholdTask copyWith({String? title, bool? completed, DateTime? dueAt, bool clearDueAt = false}) {
    final nextCompleted = completed ?? this.completed;
    return HouseholdTask(
      id: id,
      householdId: householdId,
      createdBy: createdBy,
      title: title ?? this.title,
      completed: nextCompleted,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      completedAt: nextCompleted ? (this.completedAt ?? DateTime.now().toUtc()) : null,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) => <String, dynamic>{
        if (includeId) 'id': id,
        'household_id': householdId,
        'created_by': createdBy,
        'title': title,
        'due_at': dueAt?.toUtc().toIso8601String(),
        'completed': completed,
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory HouseholdTask.fromMap(Map<String, dynamic> row) {
    final id = row['id'];
    final householdId = row['household_id'];
    final createdBy = row['created_by'];
    final title = row['title'];
    final completed = row['completed'];
    if (id is! String || householdId is! String || createdBy is! String || title is! String || completed is! bool) {
      throw const FormatException('Household task row contains invalid required fields.');
    }
    return HouseholdTask(
      id: id,
      householdId: householdId,
      createdBy: createdBy,
      title: title,
      completed: completed,
      dueAt: _readNullableDate(row['due_at']),
      completedAt: _readNullableDate(row['completed_at']),
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
    );
  }

  static DateTime? _readNullableDate(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Household task date is invalid.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Household task date is invalid.');
    return parsed.toUtc();
  }

  static DateTime _readDate(Object? value) => _readNullableDate(value) ?? (throw const FormatException('Household task timestamp is required.'));
}
