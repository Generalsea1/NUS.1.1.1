class CurrencyMetadata {
  const CurrencyMetadata(this.code, this.exponent);
  final String code;
  final int exponent;

  int get scale {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }
}

class CurrencyRegistry {
  const CurrencyRegistry._();

  static const supported = <String, CurrencyMetadata>{
    'AED': CurrencyMetadata('AED', 2),
    'AUD': CurrencyMetadata('AUD', 2),
    'BHD': CurrencyMetadata('BHD', 3),
    'CAD': CurrencyMetadata('CAD', 2),
    'CHF': CurrencyMetadata('CHF', 2),
    'EGP': CurrencyMetadata('EGP', 2),
    'EUR': CurrencyMetadata('EUR', 2),
    'GBP': CurrencyMetadata('GBP', 2),
    'JOD': CurrencyMetadata('JOD', 3),
    'JPY': CurrencyMetadata('JPY', 0),
    'KWD': CurrencyMetadata('KWD', 3),
    'OMR': CurrencyMetadata('OMR', 3),
    'QAR': CurrencyMetadata('QAR', 2),
    'SAR': CurrencyMetadata('SAR', 2),
    'USD': CurrencyMetadata('USD', 2),
  };

  static CurrencyMetadata get(String code) {
    final clean = code.trim().toUpperCase();
    final value = supported[clean];
    if (value == null) {
      throw ArgumentError.value(code, 'currencyCode', 'Unsupported currency.');
    }
    return value;
  }

  static bool isSupported(String code) => supported.containsKey(code.trim().toUpperCase());

  static int majorToMinor(int majorUnits, String currencyCode) {
    final metadata = get(currencyCode);
    return majorUnits * metadata.scale;
  }

  static int minorToMajorExact(int minorUnits, String currencyCode) {
    final metadata = get(currencyCode);
    final scale = metadata.scale;
    if (minorUnits % scale != 0) {
      throw ArgumentError.value(minorUnits, 'minorUnits', 'Value cannot be converted without loss.');
    }
    return minorUnits ~/ scale;
  }
}