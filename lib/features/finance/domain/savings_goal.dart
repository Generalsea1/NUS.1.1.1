class SavingsGoal {
  SavingsGoal({
    required String id,
    required String name,
    required int targetMinorUnits,
    required String currencyCode,
    required DateTime targetDate,
    required String progressAccountId,
    this.isArchived = false,
  })  : id = id.trim(),
        name = name.trim(),
        currencyCode = currencyCode.trim().toUpperCase(),
        progressAccountId = progressAccountId.trim() {
    if (this.id.isEmpty) throw const FormatException('Savings goal ID is required.');
    if (this.name.isEmpty) throw const FormatException('Savings goal name is required.');
    if (targetMinorUnits <= 0) throw const FormatException('Savings goal target must be positive.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(this.currencyCode)) {
      throw const FormatException('Currency must be a three-letter code.');
    }
    if (this.progressAccountId.isEmpty) {
      throw const FormatException('Progress account ID is required.');
    }
  }

  final String id;
  final String name;
  final int targetMinorUnits;
  final String currencyCode;
  final DateTime targetDate;
  final String progressAccountId;
  final bool isArchived;

  SavingsGoal archive() => copyWith(isArchived: true);
  SavingsGoal unarchive() => copyWith(isArchived: false);

  SavingsGoal copyWith({
    String? id,
    String? name,
    int? targetMinorUnits,
    String? currencyCode,
    DateTime? targetDate,
    String? progressAccountId,
    bool? isArchived,
  }) => SavingsGoal(
        id: id ?? this.id,
        name: name ?? this.name,
        targetMinorUnits: targetMinorUnits ?? this.targetMinorUnits,
        currencyCode: currencyCode ?? this.currencyCode,
        targetDate: targetDate ?? this.targetDate,
        progressAccountId: progressAccountId ?? this.progressAccountId,
        isArchived: isArchived ?? this.isArchived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetMinorUnits': targetMinorUnits,
        'currencyCode': currencyCode,
        'targetDate': targetDate.toUtc().toIso8601String(),
        'progressAccountId': progressAccountId,
        'isArchived': isArchived,
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final target = json['targetMinorUnits'];
    final currency = json['currencyCode'];
    final rawDate = json['targetDate'];
    final accountId = json['progressAccountId'];
    final archived = json['isArchived'];
    if (id is! String || name is! String || currency is! String ||
        rawDate is! String || accountId is! String || target is! int ||
        archived is! bool) {
      throw const FormatException('Savings goal JSON shape is invalid.');
    }
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null) throw const FormatException('targetDate is invalid.');
    return SavingsGoal(
      id: id,
      name: name,
      targetMinorUnits: target,
      currencyCode: currency,
      targetDate: parsedDate,
      progressAccountId: accountId,
      isArchived: archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SavingsGoal && other.id == id && other.name == name &&
      other.targetMinorUnits == targetMinorUnits &&
      other.currencyCode == currencyCode &&
      other.targetDate.toUtc() == targetDate.toUtc() &&
      other.progressAccountId == progressAccountId &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(id, name, targetMinorUnits, currencyCode,
      targetDate.toUtc(), progressAccountId, isArchived);
}

abstract interface class SavingsGoalRepository {
  Future<SavingsGoal?> getById(String id);
  Future<List<SavingsGoal>> list();
  Future<void> save(SavingsGoal goal);
  Future<void> archiveById(String id);
}
