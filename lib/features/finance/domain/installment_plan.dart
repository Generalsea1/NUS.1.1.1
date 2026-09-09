class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.currencyCode,
    required this.totalMinorUnits,
    required this.downPaymentMinorUnits,
    required this.numberOfInstallments,
    required this.paidInstallments,
    required this.firstDueDate,
  }) : assert(numberOfInstallments > 0),
       assert(paidInstallments >= 0),
       assert(paidInstallments <= numberOfInstallments),
       assert(totalMinorUnits > 0),
       assert(downPaymentMinorUnits >= 0),
       assert(downPaymentMinorUnits < totalMinorUnits);

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
    if (installmentNumber < 1 || installmentNumber > numberOfInstallments) {
      throw RangeError.range(installmentNumber, 1, numberOfInstallments, 'installmentNumber');
    }
    return baseInstallmentMinorUnits + (installmentNumber <= remainderMinorUnits ? 1 : 0);
  }

  int get remainingBalanceMinorUnits => financedMinorUnits - paidInstallmentsTotalMinorUnits;

  int get paidInstallmentsTotalMinorUnits =>
      Iterable<int>.generate(paidInstallments, (index) => installmentAmountMinorUnits(index + 1))
          .fold<int>(0, (sum, amount) => sum + amount);

  DateTime dueDateFor(int installmentNumber) {
    final amount = installmentNumber;
    if (amount < 1 || amount > numberOfInstallments) {
      throw RangeError.range(amount, 1, numberOfInstallments, 'installmentNumber');
    }
    return DateTime(firstDueDate.year, firstDueDate.month + amount - 1, firstDueDate.day);
  }
}
