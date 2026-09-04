/// Exact monetary value represented in integer minor units.
///
/// [minorUnits] never uses floating-point arithmetic. [currencyCode] is a
/// canonical ISO-style three-letter code validated at construction time.
class Money {
  factory Money({required int minorUnits, required String currencyCode}) {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code must be exactly three alphabetic characters.',
      );
    }

    return Money._(
      minorUnits: minorUnits,
      currencyCode: normalizedCurrency,
    );
  }

  const Money._({required this.minorUnits, required this.currencyCode});

  final int minorUnits;
  final String currencyCode;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'minorUnits': minorUnits,
        'currencyCode': currencyCode,
      };

  factory Money.fromJson(Map<String, dynamic> json) {
    final minorUnits = json['minorUnits'];
    final currencyCode = json['currencyCode'];

    if (minorUnits is! int) {
      throw const FormatException('Money minorUnits must be an integer.');
    }
    if (currencyCode is! String) {
      throw const FormatException('Money currencyCode must be a string.');
    }

    try {
      return Money(minorUnits: minorUnits, currencyCode: currencyCode);
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);
}
