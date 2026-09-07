import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';
import 'currency_registry.dart';
import 'expense_category.dart';
import 'expense_date.dart';
import 'expense_type.dart';
import 'money.dart';

class Expense implements DomainEntity {
  factory Expense({
    required String id,
    required Money amount,
    required ExpenseDate date,
    String userId = '',
    String? category,
    String? categoryCode,
    ExpenseType expenseType = ExpenseType.oneTime,
    String? merchant,
    String? description,
    String? paymentMethod,
    String? recurringDefinitionId,
    String? obligationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Expense ID must not be empty.');
    if (amount.minorUnits <= 0) throw ArgumentError.value(amount.minorUnits, 'amount', 'Expense amount must be greater than zero.');
    final cleanUserId = userId.trim();
    final cleanCategoryCode = categoryCode == null ? null : ExpenseCategories.requireCode(categoryCode);
    if (cleanUserId.isNotEmpty && !CurrencyRegistry.isSupported(amount.currencyCode)) {
      throw ArgumentError.value(amount.currencyCode, 'currencyCode', 'Unsupported currency for authoritative expenses.');
    }
    return Expense._(
      id: cleanId,
      userId: cleanUserId,
      amount: amount,
      date: date,
      category: _normalizeOptional(category),
      categoryCode: cleanCategoryCode,
      expenseType: expenseType,
      merchant: _normalizeOptional(merchant),
      description: _normalizeOptional(description),
      paymentMethod: _normalizeOptional(paymentMethod),
      recurringDefinitionId: _normalizeOptional(recurringDefinitionId),
      obligationId: _normalizeOptional(obligationId),
      createdAt: (createdAt ?? DateTime.now().toUtc()).toUtc(),
      updatedAt: (updatedAt ?? DateTime.now().toUtc()).toUtc(),
    );
  }

  const Expense._({required this.id, required this.userId, required this.amount, required this.date, required this.category, required this.categoryCode, required this.expenseType, required this.merchant, required this.description, required this.paymentMethod, required this.recurringDefinitionId, required this.obligationId, required this.createdAt, required this.updatedAt});

  @override final String id;
  final String userId;
  final Money amount;
  final ExpenseDate date;
  final String? category;
  final String? categoryCode;
  final ExpenseType expenseType;
  final String? merchant;
  final String? description;
  final String? paymentMethod;
  final String? recurringDefinitionId;
  final String? obligationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Expense copyWith({String? userId, Money? amount, ExpenseDate? date, String? category, String? categoryCode, ExpenseType? expenseType, String? merchant, String? description, String? paymentMethod, String? recurringDefinitionId, String? obligationId, DateTime? createdAt, DateTime? updatedAt}) => Expense(id: id, userId: userId ?? this.userId, amount: amount ?? this.amount, date: date ?? this.date, category: category ?? this.category, categoryCode: categoryCode ?? this.categoryCode, expenseType: expenseType ?? this.expenseType, merchant: merchant ?? this.merchant, description: description ?? this.description, paymentMethod: paymentMethod ?? this.paymentMethod, recurringDefinitionId: recurringDefinitionId ?? this.recurringDefinitionId, obligationId: obligationId ?? this.obligationId, createdAt: createdAt ?? this.createdAt, updatedAt: updatedAt ?? DateTime.now().toUtc());

  Map<String, dynamic> toJson() => {'id': id, 'userId': userId, 'amountMinorUnits': amount.minorUnits, 'currencyCode': amount.currencyCode, 'date': date.toIsoString(), 'category': category, 'categoryCode': categoryCode, 'expenseType': expenseType.code, 'merchant': merchant, 'description': description, 'paymentMethod': paymentMethod, 'recurringDefinitionId': recurringDefinitionId, 'obligationId': obligationId, 'createdAt': createdAt.toUtc().toIso8601String(), 'updatedAt': updatedAt.toUtc().toIso8601String()};

  factory Expense.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['userId'];
    final amountMinorUnits = json['amountMinorUnits'];
    final currencyCode = json['currencyCode'];
    final date = json['date'];
    if (id is! String) throw const FormatException('Expense id must be a string.');
    if (userId != null && userId is! String) throw const FormatException('Expense userId must be a string or null.');
    if (amountMinorUnits is! int) throw const FormatException('Expense amountMinorUnits must be an integer.');
    if (currencyCode is! String) throw const FormatException('Expense currencyCode must be a string.');
    if (date is! String) throw const FormatException('Expense date must be a string.');
    final category = _readOptionalString(json, 'category');
    final categoryCode = _readOptionalString(json, 'categoryCode');
    final merchant = _readOptionalString(json, 'merchant');
    final description = _readOptionalString(json, 'description');
    final paymentMethod = _readOptionalString(json, 'paymentMethod');
    final recurringDefinitionId = _readOptionalString(json, 'recurringDefinitionId');
    final obligationId = _readOptionalString(json, 'obligationId');
    final rawType = json['expenseType'];
    final expenseType = rawType is String ? ExpenseTypeCodec.parse(rawType) : ExpenseType.oneTime;
    final createdAt = _readOptionalDate(json['createdAt']);
    final updatedAt = _readOptionalDate(json['updatedAt']);
    try {
      return Expense(id: id, userId: userId as String? ?? '', amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode), date: ExpenseDate.fromJson(date), category: category, categoryCode: categoryCode, expenseType: expenseType, merchant: merchant, description: description, paymentMethod: paymentMethod, recurringDefinitionId: recurringDefinitionId, obligationId: obligationId, createdAt: createdAt, updatedAt: updatedAt);
    } on ArgumentError catch (error) { throw FormatException(error.message.toString()); }
  }

  static String? _normalizeOptional(String? value) { if (value == null) return null; final clean = value.trim(); return clean.isEmpty ? null : clean; }
  static String? _readOptionalString(Map<String, dynamic> json, String key) { final value = json[key]; if (value == null) return null; if (value is! String) throw FormatException('Expense $key must be a string or null.'); return value; }
  static DateTime? _readOptionalDate(Object? value) { if (value == null) return null; if (value is! String) throw const FormatException('Expense timestamp must be a string or null.'); final parsed = DateTime.tryParse(value); if (parsed == null) throw const FormatException('Expense timestamp is invalid.'); return parsed.toUtc(); }
}

abstract interface class ExpenseRepository implements DomainRepository<Expense> {}