import '../../../core/domain/domain_entity.dart';
import 'expense_date.dart';
import 'money.dart';

/// Aggregate root for a single personal expense.
///
/// The domain stores exact monetary value through [Money] and date-only
/// calendar semantics through [ExpenseDate]. Optional descriptive fields are
/// normalized without changing meaningful internal whitespace.
class Expense implements DomainEntity {
  factory Expense({
    required String id,
    required Money amount,
    required ExpenseDate date,
    String? category,
    String? merchant,
    String? description,
    String? paymentMethod,
  }) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Expense ID must not be empty.');
    }
    if (amount.minorUnits <= 0) {
      throw ArgumentError.value(
        amount.minorUnits,
        'amount',
        'Expense amount must be greater than zero.',
      );
    }

    return Expense._(
      id: cleanId,
      amount: amount,
      date: date,
      category: _normalizeOptional(category),
      merchant: _normalizeOptional(merchant),
      description: _normalizeOptional(description),
      paymentMethod: _normalizeOptional(paymentMethod),
    );
  }

  const Expense._({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.merchant,
    required this.description,
    required this.paymentMethod,
  });

  @override
  final String id;
  final Money amount;
  final ExpenseDate date;
  final String? category;
  final String? merchant;
  final String? description;
  final String? paymentMethod;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'amountMinorUnits': amount.minorUnits,
        'currencyCode': amount.currencyCode,
        'date': date.toIsoString(),
        'category': category,
        'merchant': merchant,
        'description': description,
        'paymentMethod': paymentMethod,
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final amountMinorUnits = json['amountMinorUnits'];
    final currencyCode = json['currencyCode'];
    final date = json['date'];

    if (id is! String) {
      throw const FormatException('Expense id must be a string.');
    }
    if (amountMinorUnits is! int) {
      throw const FormatException('Expense amountMinorUnits must be an integer.');
    }
    if (currencyCode is! String) {
      throw const FormatException('Expense currencyCode must be a string.');
    }
    if (date is! String) {
      throw const FormatException('Expense date must be a string.');
    }

    final category = _readOptionalString(json, 'category');
    final merchant = _readOptionalString(json, 'merchant');
    final description = _readOptionalString(json, 'description');
    final paymentMethod = _readOptionalString(json, 'paymentMethod');

    try {
      return Expense(
        id: id,
        amount: Money(
          minorUnits: amountMinorUnits,
          currencyCode: currencyCode,
        ),
        date: ExpenseDate.fromJson(date),
        category: category,
        merchant: merchant,
        description: description,
        paymentMethod: paymentMethod,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final clean = value.trim();
    return clean.isEmpty ? null : clean;
  }

  static String? _readOptionalString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expense $key must be a string or null.');
    }
    return value;
  }
}

/// Repository boundary for [Expense] aggregates.
abstract interface class ExpenseRepository
    implements DomainRepository<Expense> {}
