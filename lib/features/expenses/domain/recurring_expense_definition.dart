import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';
import 'currency_registry.dart';
import 'expense_category.dart';
import 'expense_date.dart';
import 'money.dart';

class RecurringExpenseDefinition implements DomainEntity {
  factory RecurringExpenseDefinition({
    required String id,
    required String userId,
    required String name,
    required Money amount,
    required String categoryCode,
    required String frequency,
    required bool enabled,
    required ExpenseDate startDate,
    ExpenseDate? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final cleanId = id.trim();
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    final cleanFrequency = frequency.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Recurring expense ID is required.');
    if (cleanUserId.isEmpty) throw ArgumentError.value(userId, 'userId', 'Recurring expense user ID is required.');
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name', 'Recurring expense name is required.');
    if (amount.minorUnits <= 0) throw ArgumentError.value(amount.minorUnits, 'amount', 'Recurring expense amount must be positive.');
    if (!CurrencyRegistry.isSupported(amount.currencyCode)) {
      throw ArgumentError.value(amount.currencyCode, 'currencyCode', 'Unsupported currency for authoritative expenses.');
    }
    ExpenseCategories.requireCode(categoryCode);
    if (!annualPeriods.containsKey(cleanFrequency)) {
      throw ArgumentError.value(frequency, 'frequency', 'Unsupported recurring expense frequency.');
    }
    if (endDate != null && _compare(endDate, startDate) < 0) {
      throw ArgumentError.value(endDate, 'endDate', 'End date cannot be before start date.');
    }
    return RecurringExpenseDefinition._(
      id: cleanId,
      userId: cleanUserId,
      name: cleanName,
      amount: amount,
      categoryCode: categoryCode.trim().toLowerCase(),
      frequency: cleanFrequency,
      enabled: enabled,
      startDate: startDate,
      endDate: endDate,
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      updatedAt: (updatedAt ?? DateTime.now().toUtc()).toUtc(),
    );
  }

  const RecurringExpenseDefinition._({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.categoryCode,
    required this.frequency,
    required this.enabled,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  final String id;
  final String userId;
  final String name;
  final Money amount;
  final String categoryCode;
  final String frequency;
  final bool enabled;
  final ExpenseDate startDate;
  final ExpenseDate? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get normalizedMonthlyAmount {
    final periods = annualPeriods[frequency]!;
    return roundHalfUp(amount.minorUnits * periods, 12);
  }

  bool appliesToMonth(int year, int month) {
    if (!enabled) return false;
    final requested = ExpenseDate(year: year, month: month, day: 1);
    final monthEnd = ExpenseDate(
      year: year,
      month: month,
      day: _daysInMonth(year, month),
    );
    if (_compare(monthEnd, startDate) < 0) return false;
    if (endDate != null && _compare(requested, endDate!) > 0) return false;
    return true;
  }

  RecurringExpenseDefinition copyWith({
    String? name,
    Money? amount,
    String? categoryCode,
    String? frequency,
    bool? enabled,
    ExpenseDate? startDate,
    ExpenseDate? endDate,
  }) => RecurringExpenseDefinition(
        id: id,
        userId: userId,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        categoryCode: categoryCode ?? this.categoryCode,
        frequency: frequency ?? this.frequency,
        enabled: enabled ?? this.enabled,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toMap({bool includeId = true}) => <String, dynamic>{
        if (includeId) 'id': id,
        'user_id': userId,
        'name': name,
        'amount_minor_units': amount.minorUnits,
        'currency_code': amount.currencyCode,
        'category_code': categoryCode,
        'frequency': frequency,
        'enabled': enabled,
        'start_date': startDate.toIsoString(),
        'end_date': endDate?.toIsoString(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory RecurringExpenseDefinition.fromMap(Map<String, dynamic> row) {
    final id = row['id'];
    final userId = row['user_id'];
    final name = row['name'];
    final amount = row['amount_minor_units'];
    final currency = row['currency_code'];
    final category = row['category_code'];
    final frequency = row['frequency'];
    final enabled = row['enabled'];
    final startDate = row['start_date'];
    final endDate = row['end_date'];
    if ([id, userId, name, amount, currency, category, frequency, enabled, startDate].any((v) => v == null)) {
      throw const FormatException('Recurring expense row is incomplete.');
    }
    if (id is! String || userId is! String || name is! String || amount is! int || currency is! String || category is! String || frequency is! String || enabled is! bool || startDate is! String) {
      throw const FormatException('Recurring expense row contains invalid types.');
    }
    final createdAt = _readDate(row['created_at']);
    final updatedAt = _readDate(row['updated_at']);
    return RecurringExpenseDefinition(
      id: id,
      userId: userId,
      name: name,
      amount: Money(minorUnits: amount, currencyCode: currency),
      categoryCode: category,
      frequency: frequency,
      enabled: enabled,
      startDate: ExpenseDate.fromJson(startDate),
      endDate: endDate == null ? null : ExpenseDate.fromJson(endDate as String),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static const annualPeriods = <String, int>{
    'monthly': 12,
    'weekly': 52,
    'biweekly': 26,
    'quarterly': 4,
    'yearly': 1,
  };

  static int roundHalfUp(int numerator, int denominator) =>
      (numerator + denominator ~/ 2) ~/ denominator;

  static int _compare(ExpenseDate a, ExpenseDate b) =>
      a.toIsoString().compareTo(b.toIsoString());

  static int _daysInMonth(int year, int month) {
    const days = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month != 2) return days[month - 1];
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return leap ? 29 : 28;
  }

  static DateTime _readDate(Object? value) {
    if (value is! String) throw const FormatException('Recurring expense timestamp is invalid.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Recurring expense timestamp is invalid.');
    return parsed.toUtc();
  }
}

abstract interface class RecurringExpenseRepository implements DomainRepository<RecurringExpenseDefinition> {
  Future<RecurringExpenseDefinition> setEnabled(String userId, String id, bool enabled);
}
