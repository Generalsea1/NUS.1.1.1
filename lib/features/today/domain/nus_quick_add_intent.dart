enum NusQuickAddKind { reminder, shopping, expense }

class NusQuickAddIntent {
  const NusQuickAddIntent({
    required this.kind,
    required this.normalizedText,
    this.amountMajorUnits,
    this.currencyCode,
    this.expenseCategoryCode,
    this.confidence = 0,
  });

  final NusQuickAddKind kind;
  final String normalizedText;
  final int? amountMajorUnits;
  final String? currencyCode;
  final String? expenseCategoryCode;
  final int confidence;
}

class NusQuickAddIntentClassifier {
  const NusQuickAddIntentClassifier._();

  static NusQuickAddIntent classify(String raw, {String defaultCurrency = 'EGP'}) {
    final text = _normalize(raw);
    final currency = _detectCurrency(text, defaultCurrency);
    final amount = _extractAmount(text);

    final expenseSignal = _hasAny(text, const [
      'دفعت',
      'دفعتل',
      'دفعه',
      'صرفت',
      'صرف',
      'صرفـت',
      'دفعة',
      'دفع مبلغ',
      'فاتوره',
      'سددت',
      'سداد',
      'اشتريت',
      'دفعت الحساب',
    ]);
    final shoppingSignal = _hasAny(text, const [
      'اشتري',
      'اشتريت',
      'عايز اشتري',
      'عايز اجيب',
      'اشترى',
      'جيب',
      'جيبلي',
      'هات',
      'هاتلي',
      'ناقص',
      'قائمه المشتريات',
      'مشتريات',
      'سوبر ماركت',
    ]);

    if (expenseSignal && amount != null) {
      return NusQuickAddIntent(
        kind: NusQuickAddKind.expense,
        normalizedText: text,
        amountMajorUnits: amount,
        currencyCode: currency,
        expenseCategoryCode: _category(text),
        confidence: 95,
      );
    }

    if (shoppingSignal && !expenseSignal) {
      return NusQuickAddIntent(
        kind: NusQuickAddKind.shopping,
        normalizedText: text,
        confidence: 90,
      );
    }

    return NusQuickAddIntent(
      kind: NusQuickAddKind.reminder,
      normalizedText: text,
      confidence: text.isEmpty ? 0 : 85,
    );
  }

  static int? _extractAmount(String text) {
    final match = RegExp(
      r'(?:^|\s)(\d+(?:[\.,]\d{1,2})?)(?:\s*(?:جنيه|جنيها|جنيه|egp|دولار|usd|\$|يورو|eur|€|استرليني|gbp|£))?(?=\s|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    final normalized = match.group(1)!.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;
    return parsed.round();
  }

  static String _detectCurrency(String text, String defaultCurrency) {
    if (_hasAny(text, const ['دولار', 'usd', '\$'])) return 'USD';
    if (_hasAny(text, const ['يورو', 'eur', '€'])) return 'EUR';
    if (_hasAny(text, const ['استرليني', 'gbp', '£'])) return 'GBP';
    if (_hasAny(text, const ['جنيه', 'egp'])) return 'EGP';
    return defaultCurrency.trim().toUpperCase();
  }

  static String _category(String text) {
    if (_hasAny(text, const ['كهربا', 'كهرباء', 'ميه', 'مياه', 'غاز', 'انترنت', 'نت', 'تليفون'])) return 'utilities';
    if (_hasAny(text, const ['مطعم', 'اكل', 'غدا', 'غذاء', 'سوبر ماركت', 'بقاله'])) return 'food';
    if (_hasAny(text, const ['تاكسي', 'اوبر', 'مواصلات', 'بنزين', 'مترو', 'ميكروباص'])) return 'transportation';
    if (_hasAny(text, const ['دواء', 'صيدليه', 'كشف', 'دكتور', 'طبيب'])) return 'healthcare';
    if (_hasAny(text, const ['مدرسه', 'درس', 'جامعه', 'تعليم'])) return 'education';
    if (_hasAny(text, const ['ايجار', 'شقه', 'سكن'])) return 'housing';
    if (_hasAny(text, const ['اشتراك', 'نتفليكس', 'سبوتيفاي', 'عضويه'])) return 'subscriptions';
    if (_hasAny(text, const ['صيانه', 'تصليح', 'اصلاح'])) return 'maintenance';
    if (_hasAny(text, const ['قسط', 'دين', 'سداد'])) return 'debt';
    return 'other';
  }

  static bool _hasAny(String text, List<String> needles) => needles.any(text.contains);

  static String _normalize(String value) {
    return value
        .trim()
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('،', ' ')
        .replaceAll('؛', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
