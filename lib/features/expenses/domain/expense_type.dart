enum ExpenseType {
  oneTime,
  variable,
  recurring,
}

extension ExpenseTypeCodec on ExpenseType {
  String get code => switch (this) {
        ExpenseType.oneTime => 'one_time',
        ExpenseType.variable => 'variable',
        ExpenseType.recurring => 'recurring',
      };

  static ExpenseType parse(String value) => switch (value) {
        'one_time' => ExpenseType.oneTime,
        'variable' => ExpenseType.variable,
        'recurring' => ExpenseType.recurring,
        _ => throw const FormatException('Unsupported expense type.'),
      };
}