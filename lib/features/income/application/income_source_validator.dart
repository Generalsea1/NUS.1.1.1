import '../domain/income_source.dart';

class IncomeSourceValidator {
  const IncomeSourceValidator();

  static const supportedCurrencies = <String>{
    'AUD', 'BHD', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'DZD', 'EGP',
    'EUR', 'GBP', 'HKD', 'HUF', 'ILS', 'INR', 'JOD', 'JPY', 'KES', 'KWD',
    'MAD', 'MXN', 'NGN', 'NOK', 'NZD', 'OMR', 'PLN', 'QAR', 'RUB', 'SAR',
    'SEK', 'SGD', 'THB', 'TND', 'TRY', 'USD', 'ZAR',
  };

  String? validate(IncomeSource source, {String? householdCurrencyCode}) {
    final currency = source.currencyCode.trim().toUpperCase();
    if (source.userId.trim().isEmpty) return 'المستخدم الحالي غير محدد.';
    if (source.name.trim().isEmpty) return 'اكتب اسم مصدر الدخل.';
    if (!IncomeSourceTypes.values.contains(source.sourceType) && source.sourceType != 'legacy') {
      return 'اختار نوع دخل صحيح.';
    }
    if (source.amount <= 0) return 'المبلغ لازم يكون أكبر من صفر.';
    if (!supportedCurrencies.contains(currency)) return 'العملة لازم تكون عملة مدعومة، زي EGP أو USD.';
    if (householdCurrencyCode != null &&
        currency != householdCurrencyCode.trim().toUpperCase()) {
      return 'عملة مصدر الدخل لازم تطابق عملة البيت الحالية.';
    }
    if (!IncomeFrequencies.values.contains(source.frequency)) return 'اختار تكرار دخل صحيح.';
    return null;
  }
}
