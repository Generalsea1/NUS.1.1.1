class IncomeSource {
  IncomeSource({
    this.id,
    required this.userId,
    required this.name,
    required this.sourceType,
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
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Income source user ID is required.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Income source name is required.');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Income source amount must be greater than zero.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Income source currency must be a 3-letter code.');
    }
  }

  final String? id;
  final String userId;
  final String name;
  final String sourceType;
  final int amount;
  final String currencyCode;
  final String frequency;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get normalizedMonthlyAmount => IncomeNormalization.monthly(amount, frequency);

  IncomeSource copyWith({
    String? name,
    String? sourceType,
    int? amount,
    String? currencyCode,
    String? frequency,
    bool? enabled,
  }) => IncomeSource(
        id: id,
        userId: userId,
        name: name ?? this.name,
        sourceType: sourceType ?? this.sourceType,
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
        'source_type': sourceType,
        'amount': amount,
        'currency_code': currencyCode.trim().toUpperCase(),
        'frequency': frequency,
        'enabled': enabled,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory IncomeSource.fromMap(Map<String, dynamic> row) {
    final id = row['id'];
    final userId = row['user_id'];
    final name = row['name'];
    final sourceType = row['source_type'];
    final amount = row['amount'];
    final currency = row['currency_code'];
    final frequency = row['frequency'];
    final enabled = row['enabled'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Income source id must be a non-empty string.');
    }
    if (userId is! String || userId.trim().isEmpty) {
      throw const FormatException('Income source user_id must be a non-empty string.');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Income source name must be a non-empty string.');
    }
    if (sourceType is! String || sourceType.trim().isEmpty) {
      throw const FormatException('Income source source_type must be a non-empty string.');
    }
    if (amount is! int) {
      throw const FormatException('Income source amount must be an integer.');
    }
    if (currency is! String || currency.trim().isEmpty) {
      throw const FormatException('Income source currency_code must be a string.');
    }
    if (frequency is! String || frequency.trim().isEmpty) {
      throw const FormatException('Income source frequency must be a non-empty string.');
    }
    if (enabled is! bool) {
      throw const FormatException('Income source enabled must be boolean.');
    }
    return IncomeSource(
      id: id,
      userId: userId,
      name: name,
      sourceType: sourceType,
      amount: amount,
      currencyCode: currency,
      frequency: frequency,
      enabled: enabled,
      createdAt: _readDate(row['created_at']),
      updatedAt: _readDate(row['updated_at']),
    );
  }

  static DateTime _readDate(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toUtc();
    }
    throw const FormatException('Income source timestamp is invalid.');
  }
}

class IncomeNormalization {
  const IncomeNormalization._();

  static const annualPeriods = <String, int>{
    'monthly': 12,
    'weekly': 52,
    'biweekly': 26,
    'quarterly': 4,
    'yearly': 1,
  };

  static int monthly(int amount, String frequency) {
    final periods = annualPeriods[frequency];
    if (periods == null) {
      throw ArgumentError.value(frequency, 'frequency', 'Unsupported income frequency.');
    }
    final annualAmount = amount * periods;
    return _roundHalfUp(annualAmount, 12);
  }

  static int _roundHalfUp(int numerator, int denominator) =>
      (numerator + denominator ~/ 2) ~/ denominator;
}

class IncomeSourceTypes {
  const IncomeSourceTypes._();

  static const values = <String>[
    'salary',
    'pension',
    'rent',
    'interest',
    'freelance',
    'business',
    'other',
  ];

  static const labels = <String, String>{
    'salary': 'راتب',
    'pension': 'معاش',
    'rent': 'إيجار',
    'interest': 'فوائد / عوائد',
    'freelance': 'عمل حر',
    'business': 'نشاط تجاري',
    'other': 'آخر',
    'legacy': 'الدخل الأساسي من إعداد البيت',
  };
}

class IncomeFrequencies {
  const IncomeFrequencies._();

  static const values = <String>[
    'monthly',
    'weekly',
    'biweekly',
    'quarterly',
    'yearly',
  ];

  static const labels = <String, String>{
    'monthly': 'شهري',
    'weekly': 'أسبوعي',
    'biweekly': 'كل أسبوعين',
    'quarterly': 'ربع سنوي',
    'yearly': 'سنوي',
  };
}
