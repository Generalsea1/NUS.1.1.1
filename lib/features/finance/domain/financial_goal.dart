import '../../expenses/domain/currency_registry.dart';
import '../../expenses/domain/money.dart';

const _unset = Object();

enum FinancialGoalStatus { active, paused, completed }

class FinancialGoal {
  FinancialGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    DateTime? targetDate,
    this.currentAmount,
    FinancialGoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : targetDate = targetDate == null ? null : _dateOnly(targetDate),
        status = _normalizedStatus(
          status ?? FinancialGoalStatus.active,
          currentAmount,
          targetAmount,
        ),
        createdAt = _utcDateTime(createdAt ?? DateTime.now().toUtc()),
        updatedAt = _utcDateTime(updatedAt ?? DateTime.now().toUtc()) {
    final cleanId = id.trim();
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Goal ID is required.');
    if (cleanUserId.isEmpty) throw ArgumentError.value(userId, 'userId', 'Authenticated user is required.');
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name', 'Goal name is required.');
    CurrencyRegistry.get(targetAmount.currencyCode);
    if (targetAmount.minorUnits <= 0) {
      throw ArgumentError.value(targetAmount.minorUnits, 'targetAmount', 'Goal target must be greater than zero.');
    }
    final current = currentAmount;
    if (current != null) {
      if (current.currencyCode != targetAmount.currencyCode) {
        throw ArgumentError.value(current.currencyCode, 'currentAmount', 'Current amount currency must match the target currency.');
      }
      if (current.minorUnits < 0) {
        throw ArgumentError.value(current.minorUnits, 'currentAmount', 'Current amount cannot be negative.');
      }
      if (current.minorUnits > targetAmount.minorUnits) {
        throw ArgumentError.value(current.minorUnits, 'currentAmount', 'Current amount cannot exceed the target amount.');
      }
    }
  }

  final String id;
  final String userId;
  final String name;
  final Money targetAmount;
  final DateTime? targetDate;
  final Money? currentAmount;
  final FinancialGoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => currentAmount != null && currentAmount!.minorUnits >= targetAmount.minorUnits;

  int? get progressPercent {
    final current = currentAmount;
    if (current == null) return null;
    if (current.minorUnits <= 0) return 0;
    if (current.minorUnits >= targetAmount.minorUnits) return 100;
    return (current.minorUnits * 100) ~/ targetAmount.minorUnits;
  }

  Money? get remainingAmount {
    final current = currentAmount;
    if (current == null) return null;
    final remaining = targetAmount.minorUnits - current.minorUnits;
    return Money(minorUnits: remaining > 0 ? remaining : 0, currencyCode: targetAmount.currencyCode);
  }

  int? daysRemaining({DateTime? today}) {
    final date = targetDate;
    if (date == null) return null;
    final now = _dateOnly(today ?? DateTime.now());
    return date.difference(now).inDays;
  }

  Money? requiredDailySaving({DateTime? today}) {
    final days = daysRemaining(today: today);
    final remaining = remainingAmount;
    if (currentAmount == null || targetDate == null || days == null || days <= 0 || remaining == null) return null;
    if (remaining.minorUnits <= 0) return Money(minorUnits: 0, currencyCode: targetAmount.currencyCode);
    return Money(minorUnits: (remaining.minorUnits + days - 1) ~/ days, currencyCode: targetAmount.currencyCode);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'userId': userId,
        'name': name,
        'targetAmount': targetAmount.toJson(),
        'targetDate': targetDate == null ? null : _dateOnly(targetDate!).toIso8601String().substring(0, 10),
        'currentAmount': currentAmount?.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    final rawTarget = json['targetAmount'];
    final rawCurrent = json['currentAmount'];
    final rawTargetDate = json['targetDate'];
    FinancialGoalStatus? parsedStatus;
    final statusName = json['status'];
    if (statusName is String) {
      for (final candidate in FinancialGoalStatus.values) {
        if (candidate.name == statusName) {
          parsedStatus = candidate;
          break;
        }
      }
    }
    return FinancialGoal(
      id: _requiredString(json['id'], 'id'),
      userId: _requiredString(json['userId'], 'userId'),
      name: _requiredString(json['name'], 'name'),
      targetAmount: Money.fromJson(_requiredMap(rawTarget, 'targetAmount')),
      targetDate: rawTargetDate == null ? null : _parseDateOnly(_requiredString(rawTargetDate, 'targetDate')),
      currentAmount: rawCurrent == null ? null : Money.fromJson(_requiredMap(rawCurrent, 'currentAmount')),
      status: parsedStatus,
      createdAt: DateTime.parse(_requiredString(json['createdAt'], 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json['updatedAt'], 'updatedAt')).toUtc(),
    );
  }

  FinancialGoal copyWith({
    String? name,
    Money? targetAmount,
    Object? targetDate = _unset,
    Object? currentAmount = _unset,
    FinancialGoalStatus? status,
  }) {
    return FinancialGoal(
      id: id,
      userId: userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: identical(targetDate, _unset) ? this.targetDate : targetDate as DateTime?,
      currentAmount: identical(currentAmount, _unset) ? this.currentAmount : currentAmount as Money?,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static FinancialGoalStatus _normalizedStatus(FinancialGoalStatus requested, Money? current, Money target) {
    if (current != null && current.minorUnits >= target.minorUnits) return FinancialGoalStatus.completed;
    return requested == FinancialGoalStatus.completed ? FinancialGoalStatus.active : requested;
  }

  static DateTime _dateOnly(DateTime value) => DateTime.utc(value.year, value.month, value.day);
  static DateTime _utcDateTime(DateTime value) => value.toUtc();

  static String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) throw FormatException('Financial goal $field is invalid.');
    return value;
  }

  static Map<String, dynamic> _requiredMap(Object? value, String field) {
    if (value is! Map) throw FormatException('Financial goal $field is invalid.');
    return Map<String, dynamic>.from(value);
  }

  static DateTime _parseDateOnly(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Financial goal target date is invalid.');
    return _dateOnly(parsed);
  }
}
