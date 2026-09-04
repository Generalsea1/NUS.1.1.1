import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_lifecycle_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/expense_date.dart';
import 'package:nus/features/expenses/domain/money.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  final Map<String, Expense> _store = <String, Expense>{};
  List<Expense>? listResult;
  Object? getFailure;
  Object? listFailure;
  Object? saveFailure;
  Object? deleteFailure;
  String? deletedId;

  int get saveCount => _saveCount;
  int _saveCount = 0;

  @override
  Future<Expense?> getById(String id) async {
    final failure = getFailure;
    if (failure != null) throw failure;
    return _store[id];
  }

  @override
  Future<List<Expense>> list() async {
    final failure = listFailure;
    if (failure != null) throw failure;
    return listResult ?? List<Expense>.of(_store.values);
  }

  @override
  Future<void> save(Expense entity) async {
    _saveCount++;
    final failure = saveFailure;
    if (failure != null) throw failure;
    _store[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    final failure = deleteFailure;
    if (failure != null) throw failure;
    deletedId = id;
    _store.remove(id);
  }
}

Expense _expense({
  String id = 'expense-1',
  int minorUnits = 12345,
  String currencyCode = 'USD',
  ExpenseDate? date,
  String? category = 'Food',
  String? merchant = 'Merchant',
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

void main() {
  group('ExpenseLifecycleService', () {
    test('create delegates and preserves ID, Money, currency, and date exactly', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final expense = _expense(
        id: 'caller-controlled-id',
        minorUnits: 987654321,
        currencyCode: 'eur',
        date: ExpenseDate(year: 2031, month: 12, day: 29),
      );

      final created = await service.create(expense);

      expect(created.id, expense.id);
      expect(created.amount, expense.amount);
      expect(created.amount.minorUnits, 987654321);
      expect(created.amount.currencyCode, 'EUR');
      expect(created.date, expense.date);
      expect(await repository.getById(expense.id), same(expense));
      expect(repository.saveCount, 1);
    });

    test('create propagates repository failure and reports no false success', () async {
      final repository = _FakeExpenseRepository()
        ..saveFailure = StateError('save failed');
      final service = ExpenseLifecycleService(repository: repository);
      final expense = _expense();

      await expectLater(service.create(expense), throwsA(isA<StateError>()));
      expect(await repository.getById(expense.id), isNull);
      expect(repository.saveCount, 1);
    });

    test('update delegates replacement with the same stable ID and preserves exact values', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final original = _expense(
        id: 'stable-id',
        minorUnits: 1000,
        currencyCode: 'USD',
        date: ExpenseDate(year: 2026, month: 9, day: 1),
      );
      final updated = _expense(
        id: original.id,
        minorUnits: 1001,
        currencyCode: 'USD',
        date: ExpenseDate(year: 2026, month: 9, day: 2),
        category: 'Transport',
        merchant: 'Updated Merchant',
        description: 'Updated description',
        paymentMethod: 'Cash',
      );
      await repository.save(original);

      final result = await service.update(updated);

      expect(result.id, original.id);
      expect(result.id, 'stable-id');
      expect(result.amount, updated.amount);
      expect(result.amount.minorUnits, 1001);
      expect(result.amount.currencyCode, 'USD');
      expect(result.date, updated.date);
      expect(result.category, 'Transport');
      expect(result.merchant, 'Updated Merchant');
      expect(result.description, 'Updated description');
      expect(result.paymentMethod, 'Cash');
      expect((await repository.getById(original.id))?.toJson(), updated.toJson());
    });

    test('update repository failure leaves the previously persisted aggregate unchanged', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final original = _expense(id: 'stable-id', minorUnits: 1000);
      final updated = _expense(id: original.id, minorUnits: 2000, merchant: 'Changed');
      await repository.save(original);
      final savesBeforeUpdate = repository.saveCount;
      repository.saveFailure = StateError('update failed');

      await expectLater(service.update(updated), throwsA(isA<StateError>()));

      expect((await repository.getById(original.id))?.toJson(), original.toJson());
      expect(repository.saveCount, savesBeforeUpdate + 1);
    });

    test('update never derives or generates a different ID', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final original = _expense(id: 'opaque-123');
      await repository.save(original);

      final updated = await service.update(
        _expense(id: original.id, minorUnits: 7654321, merchant: 'New merchant'),
      );

      expect(updated.id, 'opaque-123');
      expect(await repository.getById('opaque-123'), same(updated));
      expect(await repository.getById('7654321'), isNull);
    });

    test('delete delegates the exact ID and affects only the requested Expense', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final first = _expense(id: 'first');
      final second = _expense(id: 'second', merchant: 'Other');
      await repository.save(first);
      await repository.save(second);

      await service.deleteById(first.id);

      expect(repository.deletedId, 'first');
      expect(await repository.getById(first.id), isNull);
      expect(await repository.getById(second.id), same(second));
    });

    test('delete propagates repository failure', () async {
      final repository = _FakeExpenseRepository()
        ..deleteFailure = StateError('delete failed');
      final service = ExpenseLifecycleService(repository: repository);

      await expectLater(service.deleteById('expense-1'), throwsA(isA<StateError>()));
      expect(repository.deletedId, isNull);
    });

    test('getById delegates and preserves the returned aggregate', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final expense = _expense(id: 'lookup-id');
      await repository.save(expense);

      final result = await service.getById(expense.id);

      expect(result, same(expense));
      expect(result?.amount, expense.amount);
      expect(result?.date, expense.date);
    });

    test('getById propagates repository failure', () async {
      final repository = _FakeExpenseRepository()
        ..getFailure = StateError('get failed');
      final service = ExpenseLifecycleService(repository: repository);

      await expectLater(service.getById('expense-1'), throwsA(isA<StateError>()));
    });

    test('list delegates, preserves repository order, and does not mutate the returned repository list', () async {
      final repository = _FakeExpenseRepository();
      final source = <Expense>[
        _expense(id: 'third'),
        _expense(id: 'first', merchant: 'A'),
        _expense(id: 'second', merchant: 'B'),
      ];
      repository.listResult = source;
      final service = ExpenseLifecycleService(repository: repository);

      final result = await service.list();

      expect(result.map((expense) => expense.id), <String>['third', 'first', 'second']);
      expect(source.map((expense) => expense.id), <String>['third', 'first', 'second']);
      expect(() => result.add(_expense(id: 'fourth')), throwsUnsupportedError);
      expect(source, hasLength(3));
    });

    test('list propagates repository failure', () async {
      final repository = _FakeExpenseRepository()
        ..listFailure = StateError('list failed');
      final service = ExpenseLifecycleService(repository: repository);

      await expectLater(service.list(), throwsA(isA<StateError>()));
    });

    test('empty IDs are rejected at the application boundary for delete/get', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);

      await expectLater(service.deleteById(''), throwsA(isA<ArgumentError>()));
      await expectLater(service.getById('   '), throwsA(isA<ArgumentError>()));
      expect(repository.deletedId, isNull);
      expect(repository.saveCount, 0);
    });

    test('domain-invalid Expenses cannot bypass domain invariants', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);

      expect(
        () => _expense(minorUnits: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.saveCount, 0);
      expect(
        () => Expense(
          id: '',
          amount: Money(minorUnits: 1, currencyCode: 'USD'),
          date: ExpenseDate(year: 2026, month: 1, day: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await service.getById('domain-invalid'), isNull);
    });

    test('lifecycle service owns no second in-memory source of truth', () async {
      final repository = _FakeExpenseRepository();
      final service = ExpenseLifecycleService(repository: repository);
      final expense = _expense(id: 'single-source');

      await service.create(expense);
      repository._store.clear();

      expect(await service.getById(expense.id), isNull);
    });

    test('application service is isolated from unrelated feature/storage APIs', () {
      final source = File(
        'lib/features/expenses/application/expense_lifecycle_service.dart',
      ).readAsStringSync();

      expect(source, contains('ExpenseRepository'));
      expect(source, isNot(contains('LocalExpenseRepository')));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains('ScheduleStore')));
      expect(source, isNot(contains('NotificationService')));
      expect(source, isNot(contains('ReminderScheduler')));
      expect(source, isNot(contains("features/appointments")));
      expect(source, isNot(contains("features/medications")));
      expect(source, isNot(contains("features/shopping")));
    });
  });
}
