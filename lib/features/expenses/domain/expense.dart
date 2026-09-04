import '../../../core/domain/domain_entity.dart';
import 'money.dart';

/// A single persisted personal expense.
///
/// The amount is strictly positive at the expense boundary. [Money] itself
/// intentionally allows zero and negative values so it remains reusable for
/// future financial domains where signed values may be meaningful.
class Expense implements DomainEntity {
  Expense({
    required String id,
    required this.amount,
    required DateTime date,
    String? category,
    String? merchant,
    String? description,
    String? paymentMethod,
  })  : id = _requireId(id),
        date = _dateOnly(date),
        category = _normalizeOptional(category),
        merchant = _normalizeOptional(merchant),
        description = _normalizeOptional(description),
        paymentMethod = _normalizeOptional(paymentMethod) {
    if (amount.minorUnits <= 0) {
      throw ArgumentError.value(
        amount.minorUnits,
        'amount',
        'Expense amount must be greater than zero minor units.',
      );
    }
  }

  @override
  final String id;
  final Money amount;
  final DateTime date;
  final String? category;
  final String? merchant;
  final String? description;
  final String? paymentMethod;

  Expense copyWith({
    String? id,
    Money? amount,
    DateTime? date,
    String? category,
    String? merchant,
    String? description,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'amountMinorUnits': amount.minorUnits,
        'currencyCode': amount.currencyCode,
        'date': _formatDate(date),
        'category': category,
        'merchant': merchant,
        'description': description,
        'paymentMethod': paymentMethod,
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amountMinorUnits = json['amountMinorUnits'];
    final currencyCode = json['currencyCode'];
    final rawDate = json['date'];

    if (id is! String || amountMinorUnits is! int || currencyCode is! String || rawDate is! String) {
      throw const FormatException(
        'Expense requires string id/currencyCode/date and integer amountMinorUnits.',
      );
    }

    final date = _parseDateOnly(rawDate);
    return Expense(
      id: id,
      amount: Money(
        minorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
      date: date,
      category: _optionalJsonString(json, 'category'),
      merchant: _optionalJsonString(json, 'merchant'),
      description: _optionalJsonString(json, 'description'),
      paymentMethod: _optionalJsonString(json, 'paymentMethod'),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          other.id == id &&
          other.amount == amount &&
          other.date == date &&
          other.category == category &&
          other.merchant == merchant &&
          other.description == description &&
          other.paymentMethod == paymentMethod;

  @override
  int get hashCode => Object.hash(
        id,
        amount,
        date,
        category,
        merchant,
        description,
        paymentMethod,
      );

  static String _requireId(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(value, 'id', 'Expense ID must not be empty.');
    }
    return clean;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  static String? _optionalJsonString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expense field "$key" must be a string or null.');
    }
    return value;
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime _parseDateOnly(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Expense date must use YYYY-MM-DD.');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      throw const FormatException('Expense date is not a valid calendar date.');
    }
    return parsed;
  }
}

/// Repository boundary for [Expense] aggregates.
abstract interface class ExpenseRepository
    implements DomainEntityRepository<Expense> {}

/// Local alias used only to make the Expense repository contract explicit.
abstract interface class DomainEntityRepository<T extends DomainEntity> {
  Future<T?> getById(String id);
  Future<List<T>> list();
  Future<void> save(T entity);
  Future<void> deleteById(String id);
}
