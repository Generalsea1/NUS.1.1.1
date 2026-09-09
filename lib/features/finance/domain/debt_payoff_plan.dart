class DebtPayoffPlan {
  DebtPayoffPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.currencyCode,
    required this.totalBalanceMinorUnits,
    required this.monthlyPaymentMinorUnits,
    this.extraMonthlyPaymentMinorUnits = 0,
    required this.firstDueDate,
  }) {
    final cleanId = id.trim();
    final cleanUserId = userId.trim();
    final cleanTitle = title.trim();
    final cleanCurrency = currencyCode.trim().toUpperCase();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id', 'Debt plan ID is required.');
    if (cleanUserId.isEmpty) throw ArgumentError.value(userId, 'userId', 'Debt plan user ID is required.');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Debt plan title is required.');
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(cleanCurrency)) {
      throw ArgumentError.value(currencyCode, 'currencyCode', 'Debt currency must be a 3-letter code.');
    }
    if (totalBalanceMinorUnits <= 0) {
      throw ArgumentError.value(totalBalanceMinorUnits, 'totalBalanceMinorUnits', 'Debt balance must be greater than zero.');
    }
    if (monthlyPaymentMinorUnits <= 0) {
      throw ArgumentError.value(monthlyPaymentMinorUnits, 'monthlyPaymentMinorUnits', 'Monthly payment must be greater than zero.');
    }
    if (extraMonthlyPaymentMinorUnits < 0) {
      throw ArgumentError.value(extraMonthlyPaymentMinorUnits, 'extraMonthlyPaymentMinorUnits', 'Extra payment cannot be negative.');
    }

    final effectivePayment = monthlyPaymentMinorUnits + extraMonthlyPaymentMinorUnits;
    final months = (totalBalanceMinorUnits + effectivePayment - 1) ~/ effectivePayment;
    if (months > 360) {
      throw ArgumentError.value(
        months,
        'payoffMonths',
        'Debt payoff horizon cannot exceed 360 months (30 years).',
      );
    }
  }

  static const maxPayoffMonths = 360;

  final String id;
  final String userId;
  final String title;
  final String currencyCode;
  final int totalBalanceMinorUnits;
  final int monthlyPaymentMinorUnits;
  final int extraMonthlyPaymentMinorUnits;
  final DateTime firstDueDate;

  int get effectiveMonthlyPaymentMinorUnits =>
      monthlyPaymentMinorUnits + extraMonthlyPaymentMinorUnits;

  int get estimatedMonths {
    final payment = effectiveMonthlyPaymentMinorUnits;
    if (payment <= 0) return 0;
    return (totalBalanceMinorUnits + payment - 1) ~/ payment;
  }

  List<DebtPayoffInstallment> get schedule {
    final result = <DebtPayoffInstallment>[];
    var remaining = totalBalanceMinorUnits;
    var dueDate = DateTime(firstDueDate.year, firstDueDate.month, firstDueDate.day);
    var installmentNumber = 1;

    while (remaining > 0) {
      final payment = remaining < effectiveMonthlyPaymentMinorUnits
          ? remaining
          : effectiveMonthlyPaymentMinorUnits;
      remaining -= payment;
      result.add(
        DebtPayoffInstallment(
          number: installmentNumber,
          dueDate: dueDate,
          paymentMinorUnits: payment,
          remainingMinorUnits: remaining,
        ),
      );
      dueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
      installmentNumber++;
    }
    return List.unmodifiable(result);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'title': title,
        'currency_code': currencyCode.trim().toUpperCase(),
        'total_balance_minor_units': totalBalanceMinorUnits,
        'monthly_payment_minor_units': monthlyPaymentMinorUnits,
        'extra_monthly_payment_minor_units': extraMonthlyPaymentMinorUnits,
        'first_due_date': DateTime(firstDueDate.year, firstDueDate.month, firstDueDate.day).toIso8601String(),
      };
}

class DebtPayoffInstallment {
  const DebtPayoffInstallment({
    required this.number,
    required this.dueDate,
    required this.paymentMinorUnits,
    required this.remainingMinorUnits,
  });

  final int number;
  final DateTime dueDate;
  final int paymentMinorUnits;
  final int remainingMinorUnits;
}
