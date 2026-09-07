class ExpenseCategories {
  const ExpenseCategories._();

  static const codes = <String>[
    'food',
    'housing',
    'utilities',
    'transportation',
    'education',
    'healthcare',
    'insurance',
    'family',
    'subscriptions',
    'shopping',
    'entertainment',
    'debt',
    'maintenance',
    'other',
  ];

  static const labelsAr = <String, String>{
    'food': 'الغذاء',
    'housing': 'السكن',
    'utilities': 'المرافق',
    'transportation': 'المواصلات',
    'education': 'التعليم',
    'healthcare': 'الصحة',
    'insurance': 'التأمين',
    'family': 'الأسرة',
    'subscriptions': 'الاشتراكات',
    'shopping': 'التسوق',
    'entertainment': 'الترفيه',
    'debt': 'الديون',
    'maintenance': 'الصيانة',
    'other': 'أخرى',
  };

  static const labelsEn = <String, String>{
    'food': 'Food',
    'housing': 'Housing',
    'utilities': 'Utilities',
    'transportation': 'Transportation',
    'education': 'Education',
    'healthcare': 'Healthcare',
    'insurance': 'Insurance',
    'family': 'Family',
    'subscriptions': 'Subscriptions',
    'shopping': 'Shopping',
    'entertainment': 'Entertainment',
    'debt': 'Debt',
    'maintenance': 'Maintenance',
    'other': 'Other',
  };

  static bool isSupported(String code) => codes.contains(code);

  static String requireCode(String value) {
    final clean = value.trim().toLowerCase();
    if (!isSupported(clean)) {
      throw ArgumentError.value(value, 'categoryCode', 'Unsupported expense category.');
    }
    return clean;
  }
}