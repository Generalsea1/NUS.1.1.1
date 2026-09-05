import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/bills/domain/bill.dart';

void main() {
  test('bill uses exact minor units and deterministic serialization', () {
    final bill = Bill(
      id: 'b1',
      title: 'Electricity',
      amountMinorUnits: 12500,
      currencyCode: 'usd',
      dueAt: DateTime(2026, 9, 15),
    );

    expect(bill.currencyCode, 'USD');
    expect(bill.amountMinorUnits, 12500);
    expect(Bill.fromJson(bill.toJson()), bill);
    expect(bill.toJson()['amountMinorUnits'], isA<int>());
  });

  test('bill rejects invalid identity, money, currency and title', () {
    expect(() => Bill(id: '', title: 'x', amountMinorUnits: 1, currencyCode: 'USD', dueAt: DateTime(2026)), throwsArgumentError);
    expect(() => Bill(id: 'b', title: ' ', amountMinorUnits: 1, currencyCode: 'USD', dueAt: DateTime(2026)), throwsArgumentError);
    expect(() => Bill(id: 'b', title: 'x', amountMinorUnits: 0, currencyCode: 'USD', dueAt: DateTime(2026)), throwsArgumentError);
    expect(() => Bill(id: 'b', title: 'x', amountMinorUnits: 1, currencyCode: 'US', dueAt: DateTime(2026)), throwsArgumentError);
  });

  test('bill JSON rejects non-integer money', () {
    expect(
      () => Bill.fromJson({
        'id': 'b',
        'title': 'Electricity',
        'amountMinorUnits': 12.5,
        'currencyCode': 'USD',
        'dueAt': '2026-09-15T00:00:00.000',
        'isPaid': false,
      }),
      throwsFormatException,
    );
  });
}
