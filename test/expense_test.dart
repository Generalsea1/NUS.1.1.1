import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/appointments/data/local_appointment_repository.dart';
import 'package:nus/features/expenses/data/local_expense_repository.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';

Expense _expense({
  String id = 'expense-1',
  int minorUnits = 1234,
  String currencyCode = 'USD',
  ExpenseDate? date,
  String? category,
  String? merchant,
  String? description,
  String? paymentMethod,
}) => Expense(
      id: id,
      amount: Money(minorUnits: minorUnits, currencyCode: currencyCode),
      date: date ?? ExpenseDate(year: 2026, month: 9, day: 4),
      category: category,
      merchant: merchant,
      description: description,
      paymentMethod: paymentMethod,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('Money', () {
    test('stores exact integer minor units', () {
      const values = <int>[1, 99, 100, 101, 999, 1000, 1234, 99999999, 9223372036854775807];
      for (final value in values) {
        final money = Money(minorUnits: value, currencyCode: 'USD');
        expect(money.minorUnits, value);
        expect(money.currencyCode, 'USD');
      }
    });

    test('canonicalizes currency code', () {
      expect(Money(minorUnits: 1234, currencyCode: ' usd ').currencyCode, 'USD');
      expect(Money(minorUnits: 25000, currencyCode: ' EGP ').currencyCode, 'EGP');
    });

    test('rejects invalid currency formats', () {
      for (final value in <String>['', 'US', 'USDX', '12A', 'U D', 'USD!']) {
        expect(
          () => Money(minorUnits: 100, currencyCode: value),
          throwsA(isA<ArgumentError>()),
        );
      }
    });

    test('equality considers both minor units and currency', () {
      expect(
        Money(minorUnits: 100, currencyCode: 'USD'),
        Money(minorUnits: 100, currencyCode: 'usd'),
      );
      expect(
        Money(minorUnits: 100, currencyCode: 'USD'),
        isNot(Money(minorUnits: 100, currencyCode: 'EUR')),
      );
    });

    test('JSON round trip preserves exact value and currency', () {
      for (final example in <Money>[
        Money(minorUnits: 1234, currencyCode: 'USD'),
        Money(minorUnits: 999, currencyCode: 'EUR'),
        Money(minorUnits: 25000, currencyCode: 'EGP'),
      ]) {
        final restored = Money.fromJson(example.toJson());
        expect(restored.minorUnits, example.minorUnits);
        expect(restored.currencyCode, example.currencyCode);
        expect(restored, example);
      }
    });

    test('rejects non-integer persisted minor units', () {
      expect(
        () => Money.fromJson(<String, dynamic>{
          'minorUnits': 12.5,
          'currencyCode': 'USD',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Expense domain', () {
    test('rejects empty IDs and non-positive amounts', () {
      expect(() => _expense(id: '   '), throwsA(isA<ArgumentError>()));
      expect(() => _expense(minorUnits: 0), throwsA(isA<ArgumentError>()));
      expect(() => _expense(minorUnits: -1), throwsA(isA<ArgumentError>()));
    });

    test('normalizes optional text fields', () {
      final expense = _expense(
        category: '  Food  ',
        merchant: '  Store Name  ',
        description: '  Lunch  ',
        paymentMethod: '  Card  ',
      );

      expect(expense.category, 'Food');
      expect(expense.merchant, 'Store Name');
      expect(expense.description, 'Lunch');
      expect(expense.paymentMethod, 'Card');

      final empty = _expense(
        category: '   ',
        merchant: '   ',
        description: '   ',
        paymentMethod: '   ',
      );
      expect(empty.category, isNull);
      expect(empty.merchant, isNull);
      expect(empty.description, isNull);
      expect(empty.paymentMethod, isNull);
    });

    test('date is exact calendar data with no time component', () {
      final date = ExpenseDate(year: 2026, month: 9, day: 4);
      expect(date.toIsoString(), '2026-09-04');
      expect(ExpenseDate.fromJson('2026-09-04'), date);
      expect(() => ExpenseDate.fromJson('2026-9-4'), throwsA(isA<FormatException>()));
      expect(() => ExpenseDate.fromJson('2026-02-30'), throwsA(isA<FormatException>()));
    });

    test('content changes do not change caller-supplied ID', () {
      final first = _expense(
        id: 'stable-id',
        minorUnits: 1234,
        currencyCode: 'USD',
        date: ExpenseDate(year: 2026, month: 9, day: 4),
        category: 'Food',
        merchant: 'Market',
        description: 'Dinner',
        paymentMethod: 'Card',
      );
      final changed = _expense(
        id: 'stable-id',
        minorUnits: 999,
        currencyCode: 'EUR',
        date: ExpenseDate(year: 2026, month: 10, day: 1),
        category: 'Travel',
        merchant: 'Hotel',
        description: 'Room',
        paymentMethod: 'Cash',
      );
      expect(changed.id, first.id);
    });

    test('Expense JSON round trip preserves every field exactly', () {
      final original = _expense(
        id: 'expense-json-1',
        minorUnits: 25000,
        currencyCode: 'EGP',
        date: ExpenseDate(year: 2026, month: 9, day: 4),
        category: 'Food',
        merchant: 'Cafe',
        description: 'Breakfast',
        paymentMethod: 'Card',
      );

      final restored = Expense.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.date, original.date);
      expect(restored.category, original.category);
      expect(restored.merchant, original.merchant);
      expect(restored.description, original.description);
      expect(restored.paymentMethod, original.paymentMethod);
      expect(jsonEncode(restored.toJson()), jsonEncode(original.toJson()));
    });

    test('fromJson rejects malformed financial values instead of repairing them', () {
      final base = _expense().toJson();

      expect(
        () => Expense.fromJson(<String, dynamic>{...base, 'amountMinorUnits': 12.5}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Expense.fromJson(<String, dynamic>{...base, 'amountMinorUnits': 0}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Expense.fromJson(<String, dynamic>{...base, 'amountMinorUnits': -5}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => Expense.fromJson(<String, dynamic>{...base, 'currencyCode': 'USDX'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LocalExpenseRepository', () {
    test('uses the dedicated isolated storage key', () {
      expect(LocalExpenseRepository.storageKey, 'nus.expenses.v1');
      expect(LocalExpenseRepository.storageKey, isNot('nos.schedule.v1'));
      expect(LocalExpenseRepository.storageKey, isNot('nus.appointments.v1'));
      expect(LocalExpenseRepository.storageKey, isNot('nus.medications.v1'));
      expect(LocalExpenseRepository.storageKey, isNot('nus.shopping.v1'));
    });

    test('missing root and empty collection are usable', () async {
      final repository = LocalExpenseRepository();
      expect(await repository.list(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalExpenseRepository.storageKey, '[]');
      expect(await repository.list(), isEmpty);
    });

    test('malformed root is isolated on read and protected on mutation', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalExpenseRepository.storageKey, '{broken');
      final repository = LocalExpenseRepository();

      expect(await repository.list(), isEmpty);
      expect(() => repository.save(_expense()), throwsA(isA<FormatException>()));
      expect(() => repository.deleteById('missing'), throwsA(isA<FormatException>()));
      expect(prefs.getString(LocalExpenseRepository.storageKey), '{broken');
    });

    test('wrong root type is isolated without rewriting storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(<String, dynamic>{'expenses': []});
      await prefs.setString(LocalExpenseRepository.storageKey, raw);
      final repository = LocalExpenseRepository();

      expect(await repository.list(), isEmpty);
      expect(() => repository.save(_expense()), throwsA(isA<FormatException>()));
      expect(prefs.getString(LocalExpenseRepository.storageKey), raw);
    });

    test('malformed individual record does not hide valid records', () async {
      final valid = _expense(id: 'valid', minorUnits: 1234);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalExpenseRepository.storageKey,
        jsonEncode(<dynamic>[
          valid.toJson(),
          <String, dynamic>{
            'id': 'bad',
            'amountMinorUnits': 12.5,
            'currencyCode': 'USD',
            'date': '2026-09-04',
          },
        ]),
      );

      final expenses = await LocalExpenseRepository().list();
      expect(expenses.length, 1);
      expect(expenses.single.id, 'valid');
      expect(expenses.single.amount.minorUnits, 1234);
    });

    test('duplicate persisted IDs keep the first valid record deterministically', () async {
      final first = _expense(id: 'dup', minorUnits: 100);
      final second = _expense(id: 'dup', minorUnits: 999);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalExpenseRepository.storageKey,
        jsonEncode(<dynamic>[first.toJson(), second.toJson()]),
      );

      final expenses = await LocalExpenseRepository().list();
      expect(expenses.length, 1);
      expect(expenses.single.amount.minorUnits, 100);
    });

    test('save replaces by ID and preserves exact money/date', () async {
      final repository = LocalExpenseRepository();
      await repository.save(_expense(id: 'replace', minorUnits: 1234, currencyCode: 'USD'));
      await repository.save(
        _expense(
          id: 'replace',
          minorUnits: 999,
          currencyCode: 'EUR',
          date: ExpenseDate(year: 2026, month: 10, day: 1),
          category: 'Travel',
        ),
      );

      final expenses = await repository.list();
      expect(expenses.length, 1);
      expect(expenses.single.id, 'replace');
      expect(expenses.single.amount.minorUnits, 999);
      expect(expenses.single.amount.currencyCode, 'EUR');
      expect(expenses.single.date, ExpenseDate(year: 2026, month: 10, day: 1));
      expect(expenses.single.category, 'Travel');
    });

    test('delete affects only the requested ID', () async {
      final repository = LocalExpenseRepository();
      await repository.save(_expense(id: 'a', minorUnits: 100));
      await repository.save(_expense(id: 'b', minorUnits: 200));
      await repository.save(_expense(id: 'c', minorUnits: 300));

      await repository.deleteById('b');
      expect((await repository.list()).map((item) => item.id), ['a', 'c']);

      await repository.deleteById('missing');
      expect((await repository.list()).map((item) => item.id), ['a', 'c']);
    });

    test('ordering is deterministic by date then stable ID', () async {
      final repository = LocalExpenseRepository();
      await repository.save(_expense(id: 'z', date: ExpenseDate(year: 2026, month: 9, day: 5)));
      await repository.save(_expense(id: 'b', date: ExpenseDate(year: 2026, month: 9, day: 4)));
      await repository.save(_expense(id: 'a', date: ExpenseDate(year: 2026, month: 9, day: 4)));

      expect((await repository.list()).map((item) => item.id), ['a', 'b', 'z']);
    });

    test('exact financial values survive save, repository recreation, and reload', () async {
      final firstRepository = LocalExpenseRepository();
      await firstRepository.save(_expense(id: 'usd', minorUnits: 1234, currencyCode: 'USD'));
      await firstRepository.save(_expense(id: 'eur', minorUnits: 999, currencyCode: 'EUR'));
      await firstRepository.save(_expense(id: 'egp', minorUnits: 25000, currencyCode: 'EGP'));

      final secondRepository = LocalExpenseRepository();
      final expenses = await secondRepository.list();
      final byId = {for (final expense in expenses) expense.id: expense};

      expect(byId['usd']!.amount.minorUnits, 1234);
      expect(byId['usd']!.amount.currencyCode, 'USD');
      expect(byId['eur']!.amount.minorUnits, 999);
      expect(byId['eur']!.amount.currencyCode, 'EUR');
      expect(byId['egp']!.amount.minorUnits, 25000);
      expect(byId['egp']!.amount.currencyCode, 'EGP');
    });

    test('persisted payload contains exact integer money and date-only JSON', () async {
      final repository = LocalExpenseRepository();
      await repository.save(
        _expense(
          id: 'round-trip',
          minorUnits: 1234,
          currencyCode: 'USD',
          date: ExpenseDate(year: 2026, month: 9, day: 4),
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(LocalExpenseRepository.storageKey)!;
      expect(raw, contains('"amountMinorUnits":1234'));
      expect(raw, contains('"currencyCode":"USD"'));
      expect(raw, contains('"date":"2026-09-04"'));
      expect(raw, isNot(contains('1234.0')));
    });

    test('large integer money survives persistence without floating-point conversion', () async {
      const value = 9223372036854775807;
      final repository = LocalExpenseRepository();
      await repository.save(_expense(id: 'large', minorUnits: value, currencyCode: 'USD'));
      final restored = await LocalExpenseRepository().getById('large');
      expect(restored!.amount.minorUnits, value);
    });

    test('cross-feature storage keys remain isolated', () {
      expect(LocalAppointmentRepository.storageKey, isNot(LocalExpenseRepository.storageKey));
      expect(LocalMedicationRepository.storageKey, isNot(LocalExpenseRepository.storageKey));
      expect(LocalShoppingRepository.storageKey, isNot(LocalExpenseRepository.storageKey));
    });
  });
}
