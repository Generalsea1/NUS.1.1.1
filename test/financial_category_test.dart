import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/finance/data/local_financial_category_repository.dart';
import 'package:nus/features/finance/domain/financial_category.dart';

void main() {
  FinancialCategory category({
    String id = 'cat-1',
    String name = 'Salary',
    FinancialCategoryDirection direction = FinancialCategoryDirection.income,
    bool isArchived = false,
  }) => FinancialCategory(
        id: id,
        name: name,
        direction: direction,
        isArchived: isArchived,
      );

  group('FinancialCategory', () {
    test('normalizes identity and preserves direction', () {
      final value = category(id: '  cat-1  ', name: '  Salary  ');
      expect(value.id, 'cat-1');
      expect(value.name, 'Salary');
      expect(value.direction, FinancialCategoryDirection.income);
      expect(value.isArchived, isFalse);
    });

    test('rejects empty identity and name', () {
      expect(
        () => category(id: ' '),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => category(name: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('archive preserves stable identity', () {
      final archived = category().archive();
      expect(archived.id, 'cat-1');
      expect(archived.isArchived, isTrue);
    });

    test('serialization is deterministic and round-trips', () {
      final value = category(
        direction: FinancialCategoryDirection.expense,
      );
      expect(
        jsonEncode(value.toJson()),
        '{"id":"cat-1","name":"Salary","direction":"expense","isArchived":false}',
      );
      expect(FinancialCategory.fromJson(value.toJson()), value);
    });

    test('unknown direction and invalid persisted fields are rejected', () {
      expect(
        () => FinancialCategory.fromJson({
          'id': 'cat-1',
          'name': 'Salary',
          'direction': 'transfer',
          'isArchived': false,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => FinancialCategory.fromJson({
          'id': 'cat-1',
          'name': 'Salary',
          'direction': 'income',
          'isArchived': 'false',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LocalFinancialCategoryRepository', () {
    late SharedPreferences preferences;
    late LocalFinancialCategoryRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = LocalFinancialCategoryRepository(preferences);
    });

    test('uses a dedicated versioned storage namespace', () async {
      await repository.save(category());
      expect(preferences.getString(LocalFinancialCategoryRepository.storageKey), isNotNull);
      expect(preferences.getString('nus.expenses.v1'), isNull);
      expect(preferences.getString('nus.finance.accounts.v1'), isNull);
    });

    test('persists, reads, updates, and archives by stable ID', () async {
      await repository.save(category());
      expect(await repository.getById('cat-1'), category());

      await repository.save(category(name: 'Employment'));
      expect((await repository.getById('cat-1'))!.name, 'Employment');

      await repository.archiveById('cat-1');
      final archived = await repository.getById('cat-1');
      expect(archived!.id, 'cat-1');
      expect(archived.isArchived, isTrue);

      await repository.deleteById('cat-1');
      expect((await repository.getById('cat-1'))!.isArchived, isTrue);
    });

    test('isolates malformed individual records', () async {
      await preferences.setString(
        LocalFinancialCategoryRepository.storageKey,
        jsonEncode([
          category(id: 'cat-good').toJson(),
          {'id': 'broken', 'name': 'Bad', 'direction': 'unknown'},
        ]),
      );

      final values = await repository.list();
      expect(values, hasLength(1));
      expect(values.single.id, 'cat-good');
    });

    test('malformed storage root is rejected for writes', () async {
      await preferences.setString(
        LocalFinancialCategoryRepository.storageKey,
        '{not-json',
      );
      expect(
        () => repository.save(category()),
        throwsA(isA<StateError>()),
      );
    });

    test('repository is typed to the domain boundary', () {
      expect(repository, isA<FinancialCategoryRepository>());
    });
  });
}
