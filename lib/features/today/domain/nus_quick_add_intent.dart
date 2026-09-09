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
    final currency = defaultCurrency.trim().toUpperCase();
    final amount = _extractAmount(text);

    final expenseSignal = _hasAny(text, const [
      'دفعت',
      'دفعـت',
      'دفعتل',
      'صرفـت',
      'صرفت',
      'دفعة',
      'دفع مبلغ',
      'فاتورة',
    ]);
    final shoppingSignal = _hasAny(text, const [
      'اشتري',
      'اشترى',
      'اشترى',
      'جيب',
      'هات',
      'ناقص',
      'قائمة المشتريات',
      'مشتريات',
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
    final match = RegExp(r'(?:^|\s)(\d+(?:[\.,]\d{1,2})?)(?:\s*(?:جنيه|جنيها|جنية|egp|دولار|usd|\$))?(?=\s|$)', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)!;
    final normalized = raw.replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) return null;
    return parsed.round();
  }

  static String _category(String text) {
    if (_hasAny(text, const ['كهربا', 'كهرباء', 'مية', 'مياه', 'غاز', 'انترنت', 'نت', 'تليفون'])) return 'utilities';
    if (_hasAny(text, const ['مطعم', 'اكل', 'أكل', 'غدا', 'غذاء', 'سوبر ماركت'])) return 'food';
    if (_hasAny(text, const ['تاكسي', 'اوبر', 'أوبر', 'مواصلات', 'بنزين', 'مترو'])) return 'transportation';
    if (_hasAny(text, const ['دواء', 'صيدلية', 'كشف', 'دكتور', 'طبيب'])) return 'healthcare';
    if (_hasAny(text, const ['مدرسة', 'درس', 'جامعة', 'تعليم'])) return 'education';
    if (_hasAny(text, const ['ايجار', 'إيجار', 'شقة', 'سكن'])) return 'housing';
    if (_hasAny(text, const ['اشتراك', 'نتفليكس', 'سبوتيفاي', 'عضوية'])) return 'subscriptions';
    if (_hasAny(text, const ['صيانة', 'تصليح'])) return 'maintenance';
    if (_hasAny(text, const ['قسط', 'دين', 'سداد'])) return 'debt';
    return 'other';
  }

  static bool _hasAny(String text, List<String> needles) => needles.any(text.contains);

  static String _normalize(String value) {
    return value
        .trim()
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
        .replaceAll('ة', 'ه');
  }
}
