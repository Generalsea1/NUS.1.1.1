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
  int saveCount = 0;
  StateError? listFailure;
  StateError? saveFailure;
  StateError? deleteFailure;
  Completer<void>? saveCompleter;
  bool blockSave = false;
  final List<String> deletedIds = <String>[];

  @override
  Future<Expense?> getById(String id) async {
    return _store[id];
  }

  @override
  Future<List<Expense>> list() async {
    if (listFailure != null) throw listFailure!;
    return _store.values.toList();
  }

  @override
  Future<void> save(Expense expense) async {
    saveCount++;
    if (saveFailure != null) throw saveFailure!;
    if (blockSave) {
      saveCompleter = Completer<void>();
      await saveCompleter!.future;
    }
    _store[expense.id] = expense;
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
