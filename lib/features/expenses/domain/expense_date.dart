/// Calendar date value object for expenses.
///
/// It deliberately contains no time-of-day or timezone information. The JSON
/// representation is always the locale-independent `YYYY-MM-DD` form.
class ExpenseDate {
  factory ExpenseDate({required int year, required int month, required int day}) {
    if (year < 1 || year > 9999) {
      throw ArgumentError.value(year, 'year', 'Year must be between 1 and 9999.');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'Month must be between 1 and 12.');
    }

    final maxDay = _daysInMonth(year, month);
    if (day < 1 || day > maxDay) {
      throw ArgumentError.value(day, 'day', 'Day is invalid for the selected month.');
    }

    return ExpenseDate._(year: year, month: month, day: day);
  }

  const ExpenseDate._({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  String toIsoString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  String toJson() => toIsoString();

  factory ExpenseDate.fromJson(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw const FormatException('Expense date must use YYYY-MM-DD.');
    }

    try {
      return ExpenseDate(
        year: int.parse(match.group(1)!),
        month: int.parse(match.group(2)!),
        day: int.parse(match.group(3)!),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  static int _daysInMonth(int year, int month) {
    const days = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month != 2) return days[month - 1];

    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    return leap ? 29 : 28;
  }

  @override
  bool operator ==(Object other) =>
      other is ExpenseDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
