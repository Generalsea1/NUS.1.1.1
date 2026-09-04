import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_lifecycle_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/presentation/expense_page.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  final Map<String, Expense> _store = <String, Expense>{};
  Object? listFailure;
  Object? saveFailure;
  Object? deleteFailure;
  final List<String> deletedIds = <String>[];
  int saveCount = 0;
  bool blockSave = false;
  Completer<void>? saveCompleter;

  @override
  Future<Expense?> getById(String id) async => _store[id];

  @override
  Future<List<Expense>> list() async {
    if (listFailure != null) throw listFailure!;
    return List<Expense>.of(_store.values);
  }

  @override
  Future<void> save(Expense entity) async {
    saveCount++;
    if (saveFailure != null) throw saveFailure!;
    if (blockSave) {
      saveCompleter ??= Completer<void>();
      await saveCompleter!.future;
    }
    _store[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    if (deleteFailure != null) throw deleteFailure!;
    deletedIds.add(id);
    _store.remove(id);
  }
}

Expense _expense({
  String id = 'expense-1',
  int minorUnits = 1234,
  String currencyCode = 'USD',
  ExpenseDate? date,
  String? category = 'Food',
  String? merchant = 'Market',
  String? description = 'Lunch',
  String? paymentMethod = 'Card',
}) => Expense(
      id: id,
      amount: Money(minorUnits: minorUnits, currencyCode: currencyCode),
      date: date ?? ExpenseDate(year: 2026, month: 9, day: 4),
      category: category,
      merchant: merchant,
      description: description,
      paymentMethod: paymentMethod,
    );

Widget _app(ExpenseLifecycleService service) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ExpensePage(service: service),
      ),
    );

Future<void> _openCreate(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.text('إضافة مصروف'));
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  final save = find.text('حفظ المصروف');
  final scrollable = find.byType(ListView);
  await tester.scrollUntilVisible(save, 500, scrollable: scrollable);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> _fillMinimalValidExpense(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '1.01');
  await tester.enterText(find.byType(TextField).at(1), 'USD');
  await tester.enterText(find.byType(TextField).at(2), 'Test');
}

void main() {
  group('Expense amount conversion', () {
    test('uses exact integer minor units for supported decimal input', () {
      const cases = <String, int>{
        '1': 100,
        '1.01': 101,
        '9.99': 999,
        '10': 1000,
        '12.34': 1234,
        '99.99': 9999,
        '100': 10000,
        '1234.56': 123456,
      };
      for (final entry in cases.entries) {
        expect(parseExpenseAmountToMinorUnits(entry.key), entry.value);
      }
    });

    test('rejects malformed, non-positive and over-precision input', () {
      for (final value in <String>['', '0', '-1', '1.', '.50', '1.234', 'abc']) {
        expect(
          () => parseExpenseAmountToMinorUnits(value),
          throwsA(isA<FormatException>()),
          reason: value,
        );
      }
    });

    test('formats Money without floating-point conversion', () {
      expect(formatExpenseAmount(Money(minorUnits: 1, currencyCode: 'USD')), '0.01');
      expect(formatExpenseAmount(Money(minorUnits: 123456, currencyCode: 'USD')), '1234.56');
    });
  });

  group('Expense UI', () {
    testWidgets('list has explicit loading, success and empty states', (tester) async {
      final repository = _FakeExpenseRepository()
        .._store['a'] = _expense(id: 'a', minorUnits: 100)
        .._store['b'] = _expense(id: 'b', minorUnits: 200, merchant: 'Other');
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('1.00 USD'), findsOneWidget);
      expect(find.text('2.00 USD'), findsOneWidget);

      final emptyRepository = _FakeExpenseRepository();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: emptyRepository)));
      await tester.pumpAndSettle();
      expect(find.text('لسه مفيش مصروفات'), findsOneWidget);
      expect(find.text('إضافة مصروف'), findsOneWidget);
    });

    testWidgets('list error state retries successfully', (tester) async {
      final repository = _FakeExpenseRepository()..listFailure = StateError('load');
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await tester.pumpAndSettle();
      expect(find.text('مش قادرين نحمّل المصروفات'), findsOneWidget);
      repository.listFailure = null;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('لسه مفيش مصروفات'), findsOneWidget);
    });

    testWidgets('create form exposes required and optional fields', (tester) async {
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: _FakeExpenseRepository())));
      await _openCreate(tester);
      for (final label in <String>['المبلغ', 'العملة', 'الفئة', 'التاجر', 'ملاحظة', 'طريقة الدفع']) {
        expect(find.widgetWithText(TextField, label), findsOneWidget);
      }
      expect(find.text('التاريخ'), findsOneWidget);
    });

    testWidgets('valid create preserves amount, currency, date and optional values', (tester) async {
      final repository = _FakeExpenseRepository();
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await _openCreate(tester);
      await tester.enterText(find.byType(TextField).at(0), '12.34');
      await tester.enterText(find.byType(TextField).at(1), 'eur');
      await tester.enterText(find.byType(TextField).at(2), 'Transport');
      await tester.enterText(find.byType(TextField).at(3), 'Taxi');
      await tester.enterText(find.byType(TextField).at(4), 'Airport ride');
      await tester.enterText(find.byType(TextField).at(5), 'Cash');
      await _tapSave(tester);

      final stored = repository._store.values.single;
      expect(stored.amount.minorUnits, 1234);
      expect(stored.amount.currencyCode, 'EUR');
      expect(stored.date, ExpenseDate(year: 2026, month: 9, day: 4));
      expect(stored.category, 'Transport');
      expect(stored.merchant, 'Taxi');
      expect(stored.description, 'Airport ride');
      expect(stored.paymentMethod, 'Cash');
    });

    testWidgets('invalid required data and currency are rejected before save', (tester) async {
      final repository = _FakeExpenseRepository();
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await _openCreate(tester);
      await _tapSave(tester);
      expect(find.text('اكتب مبلغ أكبر من صفر وبحد أقصى منزلتين عشريتين.'), findsOneWidget);
      expect(repository.saveCount, 0);

      await tester.enterText(find.byType(TextField).at(0), '10');
      await tester.enterText(find.byType(TextField).at(1), 'US');
      await _tapSave(tester);
      expect(find.text('العملة لازم تكون 3 حروف، زي USD.'), findsOneWidget);
      expect(repository.saveCount, 0);
    });

    testWidgets('date picker keeps date-only semantics', (tester) async {
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: _FakeExpenseRepository())));
      await _openCreate(tester);
      await tester.tap(find.text('اختار'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      final day = find.text('15').last;
      if (tester.any(day)) {
        await tester.tap(day);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.text('2026-09-15'), findsOneWidget);
      }
    });

    testWidgets('save failure leaves the form open and usable', (tester) async {
      final repository = _FakeExpenseRepository()..saveFailure = StateError('save');
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await _openCreate(tester);
      await tester.enterText(find.byType(TextField).at(0), '10');
      await _tapSave(tester);
      expect(find.text('مصروف جديد'), findsOneWidget);
      expect(find.text('حصلت مشكلة أثناء الحفظ. جرّب تاني.'), findsOneWidget);
    });

    testWidgets('duplicate create submission is prevented while save is pending', (tester) async {
      final repository = _FakeExpenseRepository()..blockSave = true;
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await _openCreate(tester);
      await _fillMinimalValidExpense(tester);
      final save = find.text('حفظ المصروف');
      final scrollable = find.byType(ListView);
      await tester.scrollUntilVisible(save, 500, scrollable: scrollable);
      await tester.tap(save);
      await tester.pump();
      expect(repository.saveCount, 1);
      expect(find.text('بيتحفظ…'), findsOneWidget);
      repository.saveCompleter!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('edit loads exact values and preserves stable ID', (tester) async {
      final repository = _FakeExpenseRepository()
        .._store['stable-id'] = _expense(id: 'stable-id', minorUnits: 1001);
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10.01 USD'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل مصروف'), findsOneWidget);
      expect(find.text('2026-09-04'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '20.50');
      await _tapSave(tester);
      final updated = repository._store['stable-id']!;
      expect(updated.id, 'stable-id');
      expect(updated.amount.minorUnits, 2050);
    });

    testWidgets('delete confirmation cancels or deletes only the selected expense', (tester) async {
      final repository = _FakeExpenseRepository()
        .._store['a'] = _expense(id: 'a', minorUnits: 100)
        .._store['b'] = _expense(id: 'b', minorUnits: 200);
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await tester.pumpAndSettle();

      final firstMenu = find.byType(PopupMenuButton<String>).first;
      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(repository.deletedIds, isEmpty);

      await tester.tap(firstMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(repository.deletedIds, ['a']);
      expect(repository._store.containsKey('b'), isTrue);
    });

    testWidgets('delete failure is visible and does not remove the expense', (tester) async {
      final repository = _FakeExpenseRepository()
        .._store['a'] = _expense(id: 'a')
        ..deleteFailure = StateError('delete');
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(find.text('حصلت مشكلة في الحذف. جرّب تاني.'), findsOneWidget);
      expect(repository._store.containsKey('a'), isTrue);
    });

    testWidgets('navigation during pending save does not update disposed form state', (tester) async {
      final repository = _FakeExpenseRepository()..blockSave = true;
      await tester.pumpWidget(_app(ExpenseLifecycleService(repository: repository)));
      await _openCreate(tester);
      await _fillMinimalValidExpense(tester);
      final save = find.text('حفظ المصروف');
      final scrollable = find.byType(ListView);
      await tester.scrollUntilVisible(save, 500, scrollable: scrollable);
      await tester.tap(save);
      await tester.pump();
      Navigator.of(tester.element(find.text('مصروف جديد'))).pop();
      repository.saveCompleter!.complete();
      await tester.pumpAndSettle();
    });

    test('presentation layer depends on lifecycle only and avoids persistence APIs', () {
      final source = File('lib/features/expenses/presentation/expense_page.dart').readAsStringSync();
      expect(source, contains("application/expense_lifecycle_service.dart"));
      expect(source, isNot(contains('LocalExpenseRepository')));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('storageKey')));
    });
  });
}
