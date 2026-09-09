class InstallmentPlan {
  static const maxInstallments = 120;

  factory InstallmentPlan({
    required String id,
    required String userId,
    required String title,
    required String currencyCode,
    required int totalMinorUnits,
    required int downPaymentMinorUnits,
    required int numberOfInstallments,
    required int paidInstallments,
    required DateTime firstDueDate,
  }) {
    final cleanId = id.trim();
    final cleanUserId = userId.trim();
    final cleanTitle = title.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Installment plan ID is required.');
    if (cleanUserId.isEmpty) throw ArgumentError.value(userId, 'userId', 'Installment plan user ID is required.');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Installment plan title is required.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Installment currency must be a 3-letter code.');
    }
    if (totalMinorUnits <= 0) throw ArgumentError.value(totalMinorUnits, 'totalMinorUnits', 'Total must be greater than zero.');
    if (downPaymentMinorUnits < 0 || downPaymentMinorUnits >= totalMinorUnits) {
      throw ArgumentError.value(downPaymentMinorUnits, 'downPaymentMinorUnits', 'Down payment must be between zero and the total.');
    }
    if (numberOfInstallments <= 0 || numberOfInstallments > maxInstallments) {
      throw ArgumentError.value(
        numberOfInstallments,
        'numberOfInstallments',
        'Number of installments must be between 1 and $maxInstallments.',
      );
    }
    if (paidInstallments < 0 || paidInstallments > numberOfInstallments) {
      throw ArgumentError.value(paidInstallments, 'paidInstallments', 'Paid installments must be within the plan.');
    }
    return InstallmentPlan._(
      id: cleanId,
      userId: cleanUserId,
      title: cleanTitle,
      currencyCode: cleanCurrency,
      totalMinorUnits: totalMinorUnits,
      downPaymentMinorUnits: downPaymentMinorUnits,
      numberOfInstallments: numberOfInstallments,
      paidInstallments: paidInstallments,
      firstDueDate: DateTime(firstDueDate.year, firstDueDate.month, firstDueDate.day),
    );
  }

  const InstallmentPlan._({
    required this.id,
    required this.userId,
    required this.title,
    required this.currencyCode,
    required this.totalMinorUnits,
    required this.downPaymentMinorUnits,
    required this.numberOfInstallments,
    required this.paidInstallments,
    required this.firstDueDate,
  });

  final String id;
  final String userId;
  final String title;
  final String currencyCode;
  final int totalMinorUnits;
  final int downPaymentMinorUnits;
  final int numberOfInstallments;
  final int paidInstallments;
  final DateTime firstDueDate;

  int get financedMinorUnits => totalMinorUnits - downPaymentMinorUnits;
  int get remainingInstallments => numberOfInstallments - paidInstallments;
  int get baseInstallmentMinorUnits => financedMinorUnits ~/ numberOfInstallments;
  int get remainderMinorUnits => financedMinorUnits % numberOfInstallments;

  int installmentAmountMinorUnits(int installmentNumber) {
    _validateInstallmentNumber(installmentNumber);
    return baseInstallmentMinorUnits + (installmentNumber <= remainderMinorUnits ? 1 : 0);
  }

  int get remainingBalanceMinorUnits => financedMinorUnits - paidInstallmentsTotalMinorUnits;

  int get paidInstallmentsTotalMinorUnits =>
      Iterable<int>.generate(paidInstallments, (index) => installmentAmountMinorUnits(index + 1))
          .fold<int>(0, (sum, amount) => sum + amount);

  DateTime dueDateFor(int installmentNumber) {
    _validateInstallmentNumber(installmentNumber);
    return _addMonths(firstDueDate, installmentNumber - 1);
  }

  static DateTime _addMonths(DateTime date, int months) {
    final absoluteMonth = date.month - 1 + months;
    final year = date.year + absoluteMonth ~/ 12;
    final month = absoluteMonth % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  Map<String, dynamic> toMap({bool includeId = true}) => <String, dynamic>{
        if (includeId) 'id': id,
        'user_id': userId,
        'title': title,
        'currency_code': currencyCode,
        'total_minor_units': totalMinorUnits,
        'down_payment_minor_units': downPaymentMinorUnits,
        'number_of_installments': numberOfInstallments,
        'paid_installments': paidInstallments,
        'first_due_date': firstDueDate.toIso8601String().substring(0, 10),
      };

  factory InstallmentPlan.fromMap(Map<String, dynamic> row) => InstallmentPlan(
        id: _requiredString(row['id'], 'id'),
        userId: _requiredString(row['user_id'], 'user_id'),
        title: _requiredString(row['title'], 'title'),
        currencyCode: _requiredString(row['currency_code'], 'currency_code'),
        totalMinorUnits: _requiredInt(row['total_minor_units'], 'total_minor_units'),
        downPaymentMinorUnits: _requiredInt(row['down_payment_minor_units'], 'down_payment_minor_units'),
        numberOfInstallments: _requiredInt(row['number_of_installments'], 'number_of_installments'),
        paidInstallments: _requiredInt(row['paid_installments'], 'paid_installments'),
        firstDueDate: _requiredDate(row['first_due_date'], 'first_due_date'),
      );

  static String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Installment plan $field must be a non-empty string.');
    }
    return value;
  }

  static int _requiredInt(Object? value, String field) {
    if (value is! int) throw FormatException('Installment plan $field must be an integer.');
    return value;
  }

  static DateTime _requiredDate(Object? value, String field) {
    if (value is! String) throw FormatException('Installment plan $field must be a date string.');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Installment plan $field is invalid.');
    return parsed;
  }

  void _validateInstallmentNumber(int installmentNumber) {
    if (installmentNumber < 1 || installmentNumber > numberOfInstallments) {
      throw RangeError.range(installmentNumber, 1, numberOfInstallments, 'installmentNumber');
    }
  }
}
