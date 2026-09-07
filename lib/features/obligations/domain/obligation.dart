class Obligation {
  Obligation({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.amount,
    required this.currencyCode,
    required this.frequency,
    required this.enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc() {
    final cleanUserId = userId.trim();
    final cleanName = name.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    if (cleanUserId.isEmpty) throw ArgumentError.value(userId, 'userId', 'Obligation user ID is required.');
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name', 'Obligation name is required.');
    if (amount <= 0) throw ArgumentError.value(amount, 'amount', 'Obligation amount must be greater than zero.');
    if (!ObligationTypes.values.contains(type)) throw ArgumentError.value(type, 'type', 'Unsupported obligation type.');
    if (!ObligationFrequencies.values.contains(frequency)) throw ArgumentError.value(frequency, 'frequency', 'Unsupported obligation frequency.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) throw ArgumentError.value(currencyCode, 'currencyCode', 'Obligation currency must be a 3-letter code.');
  }

  final String? id;
  final String userId;
  final String name;
  final String type;
  final int amount;
  final String currencyCode;
  final String frequency;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get normalizedMonthlyAmount => ObligationNormalization.monthly(amount, frequency);
  bool get isLegacy => type == 'legacy';

  Obligation copyWith({String? name, String? type, int? amount, String? currencyCode, String? frequency, bool? enabled}) => Obligation(
        id: id,
        userId: userId,
        name: name ?? this.name,
        type: type ?? this.type,
        amount: amount ?? this.amount,
        currencyCode: currencyCode ?? this.currencyCode,
        frequency: frequency ?? this.frequency,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap({bool includeId = true}) => <String, dynamic>{
        if (includeId && id != null) 'id': id,
        'user_id': userId,
        'name': name.trim(),
        'type': type,
        'amount': amount,
        'currency_code': currencyCode.trim().toUpperCase(),
        'frequency': frequency,
        'enabled': enabled,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory Obligation.fromMap(Map<String, dynamic> row) {
    final id = row['id'];
    if (id is! String || id.trim().isEmpty) throw const FormatException('Obligation id must be a non-empty string.');
    final userId = row['user_id'];
    if (userId is! String || userId.trim().isEmpty) throw const FormatException('Obligation user_id must be a non-empty string.');
    final name = row['name'];
    if (name is! String || name.trim().isEmpty) throw const FormatException('Obligation name must be a non-empty string.');
    final type = row['type'];
    if (type is! String || type.trim().isEmpty) throw const FormatException('Obligation type must be a non-empty string.');
    final amount = row['amount'];
    if (amount is! int || amount <= 0) throw const FormatException('Obligation amount must be a positive integer.');
    final currency = row['currency_code'];
    if (currency is! String || currency.trim().isEmpty) throw const FormatException('Obligation currency_code must be a string.');
    final frequency = row['frequency'];
    if (frequency is! String || frequency.trim().isEmpty) throw const FormatException('Obligation frequency must be a non-empty string.');
    final enabled = row['enabled'];
    if (enabled is! bool) throw const FormatException('Obligation enabled must be boolean.');
    return Obligation(id: id, userId: userId, name: name, type: type, amount: amount, currencyCode: currency, frequency: frequency, enabled: enabled, createdAt: _readDate(row['created_at']), updatedAt: _readDate(row['updated_at']));
  }

  static DateTime _readDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    throw const FormatException('Obligation timestamp is invalid.');
  }
}

class ObligationNormalization {
  const ObligationNormalization._();
  static const annualPeriods = <String, int>{'monthly': 12, 'weekly': 52, 'biweekly': 26, 'quarterly': 4, 'yearly': 1};
  static int monthly(int amount, String frequency) {
    final periods = annualPeriods[frequency];
    if (periods == null) throw ArgumentError.value(frequency, 'frequency', 'Unsupported obligation frequency.');
    final annualAmount = amount * periods;
    return _roundHalfUp(annualAmount, 12);
  }
  static int _roundHalfUp(int numerator, int denominator) => (numerator + denominator ~/ 2) ~/ denominator;
}

class ObligationTypes {
  const ObligationTypes._();
  static const values = <String>['rent','loan','school','utilities','insurance','subscription','family_support','transportation','other','legacy'];
  static const labels = <String,String>{
    'rent':'إيجار','loan':'قسط قرض','school':'مدرسة','utilities':'مرافق','insurance':'تأمين','subscription':'اشتراك','family_support':'دعم أسري','transportation':'التزام نقل','other':'أخرى','legacy':'التزام أولي من إعداد البيت',
  };
}

class ObligationFrequencies {
  const ObligationFrequencies._();
  static const values = <String>['monthly','weekly','biweekly','quarterly','yearly'];
  static const labels = <String,String>{'monthly':'شهري','weekly':'أسبوعي','biweekly':'كل أسبوعين','quarterly':'ربع سنوي','yearly':'سنوي'};
}
