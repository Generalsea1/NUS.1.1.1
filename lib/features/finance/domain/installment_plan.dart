class InstallmentPlan {
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
    if (numberOfInstallments <= 0) {
      throw ArgumentError.value(numberOfInstallments, 'numberOfInstallments', 'Number of installments must be greater than zero.');
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
    return DateTime(firstDueDate.year, firstDueDate.month + installmentNumber - 1, firstDueDate.day);
  }

  void _validateInstallmentNumber(int installmentNumber) {
    if (installmentNumber < 1 || installmentNumber > numberOfInstallments) {
      throw RangeError.range(installmentNumber, 1, numberOfInstallments, 'installmentNumber');
    }
  }
}
