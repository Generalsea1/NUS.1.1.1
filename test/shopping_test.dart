import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/appointments/data/local_appointment_repository.dart';
import 'package:nus/features/medications/data/local_medication_repository.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';
import 'package:nus/features/shopping/domain/shopping_item.dart';
import 'package:nus/features/shopping/domain/shopping_list.dart';

ShoppingItem _item({
  String id = 'item-1',
  String name = 'Milk',
  String? quantity,
  bool isCompleted = false,
}) => ShoppingItem(
      id: id,
      name: name,
      quantity: quantity,
      isCompleted: isCompleted,
    );

ShoppingList _list({
  String id = 'list-1',
  String name = 'Groceries',
  List<ShoppingItem> items = const <ShoppingItem>[],
}) => ShoppingList(id: id, name: name, items: items);

Map<String, dynamic> _storedLists(List<Map<String, dynamic>> lists) =>
    <String, dynamic>{'lists': lists};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ShoppingItem domain', () {
    test('valid item accepts optional quantity and deterministic completion state', () {
      final item = _item(quantity: '2 boxes');

      expect(item.id, 'item-1');
      expect(item.name, 'Milk');
      expect(item.quantity, '2 boxes');
      expect(item.isCompleted, isFalse);
      expect(item, isA<ShoppingItem>());
    });

    test('invalid item ID is rejected', () {
      expect(
        () => _item(id: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid item name is rejected after trimming', () {
      expect(
        () => _item(name: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('item names are trimmed while quantity remains opaque text', () {
      final item = _item(name: '  Apples  ', quantity: '1 kg');

      expect(item.name, 'Apples');
      expect(item.quantity, '1 kg');
    });

    test('item round-trip preserves all fields', () {
      final item = _item(quantity: '2 boxes', isCompleted: true);
      final decoded = ShoppingItem.fromJson(item.toJson());

      expect(decoded.toJson(), item.toJson());
    });

    test('malformed item JSON is rejected', () {
      expect(
        () => ShoppingItem.fromJson(<String, dynamic>{'id': 'item-1'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ShoppingItem.fromJson(<String, dynamic>{
          'id': 'item-1',
          'name': 'Milk',
          'quantity': 2,
          'isCompleted': false,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ShoppingItem.fromJson(<String, dynamic>{
          'id': 'item-1',
          'name': 'Milk',
          'isCompleted': 'false',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ShoppingList aggregate', () {
    test('valid list is the aggregate root and owns its items', () {
      final list = _list(items: <ShoppingItem>[
        _item(id: 'item-1'),
      ]);

      expect(list.id, 'list-1');
      expect(list.name, 'Groceries');
      expect(list.items.single.id, 'item-1');
      expect(list.items, isA<List<ShoppingItem>>());
    });

    test('invalid list ID is rejected', () {
      expect(
        () => _list(id: ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('invalid list name is rejected after trimming', () {
      expect(
        () => _list(name: '\t'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('duplicate item IDs are rejected inside one aggregate', () {
      expect(
        () => _list(items: <ShoppingItem>[
          _item(id: 'same', name: 'Milk'),
          _item(id: 'same', name: 'Bread'),
        ]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('aggregate item collection cannot be mutated externally', () {
      final input = <ShoppingItem>[_item()];
      final list = _list(items: input);
      input.add(_item(id: 'item-2', name: 'Bread'));

      expect(list.items.length, 1);
      expect(() => list.items.add(_item(id: 'item-2')), throwsUnsupportedError);
    });

    test('add item appends without changing existing item IDs', () {
      final list = _list(items: <ShoppingItem>[_item()]);
      final updated = list.addItem(_item(id: 'item-2', name: 'Bread'));

      expect(updated.items.map((item) => item.id), ['item-1', 'item-2']);
      expect(updated.id, list.id);
    });

    test('adding duplicate item ID is rejected', () {
      final list = _list(items: <ShoppingItem>[_item()]);

      expect(
        () => list.addItem(_item(name: 'Different name')),
        throwsA(isA<StateError>()),
      );
    });

    test('update item replaces the owned child by stable ID', () {
      final list = _list(items: <ShoppingItem>[_item(quantity: '1')]);
      final updated = list.updateItem(_item(quantity: '3', isCompleted: true));

      expect(updated.items.single.id, 'item-1');
      expect(updated.items.single.name, 'Milk');
      expect(updated.items.single.quantity, '3');
      expect(updated.items.single.isCompleted, isTrue);
    });

    test('update of a non-existing item is rejected', () {
      final list = _list(items: <ShoppingItem>[_item()]);

      expect(
        () => list.updateItem(_item(id: 'missing', name: 'Bread')),
        throwsA(isA<StateError>()),
      );
    });

    test('remove item affects only the requested child', () {
      final list = _list(items: <ShoppingItem>[
        _item(id: 'item-1', name: 'Milk'),
        _item(id: 'item-2', name: 'Bread'),
      ]);
      final updated = list.removeItem('item-1');

      expect(updated.items.map((item) => item.id), ['item-2']);
      expect(updated.id, list.id);
    });

    test('removing a non-existing item is a deterministic no-op', () {
      final list = _list(items: <ShoppingItem>[_item()]);

      expect(list.removeItem('missing').toJson(), list.toJson());
    });

    test('completion mutation preserves the item ID', () {
      final list = _list(items: <ShoppingItem>[_item()]);
      final completed = list.setItemCompleted('item-1', true);
      final toggled = completed.toggleItem('item-1');

      expect(completed.items.single.id, 'item-1');
      expect(completed.items.single.isCompleted, isTrue);
      expect(toggled.items.single.id, 'item-1');
      expect(toggled.items.single.isCompleted, isFalse);
    });

    test('completion mutation of a missing item is rejected', () {
      final list = _list();

      expect(
        () => list.setItemCompleted('missing', true),
        throwsA(isA<StateError>()),
      );
      expect(
        () => list.toggleItem('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('renaming item preserves item ID', () {
      final list = _list(items: <ShoppingItem>[_item()]);
      final updated = list.updateItem(_item(name: 'Whole milk'));

      expect(updated.items.single.id, 'item-1');
      expect(updated.items.single.name, 'Whole milk');
    });

    test('list round-trip preserves logical item order', () {
      final list = _list(items: <ShoppingItem>[
        _item(id: 'b', name: 'Bread'),
        _item(id: 'a', name: 'Apples', isCompleted: true),
      ]);
      final decoded = ShoppingList.fromJson(list.toJson());

      expect(decoded.toJson(), list.toJson());
    });

    test('malformed list JSON is rejected', () {
      expect(
        () => ShoppingList.fromJson(<String, dynamic>{
          'id': 'list-1',
          'name': 'Groceries',
          'items': 'not-a-list',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ShoppingList.fromJson(<String, dynamic>{
          'id': 'list-1',
          'name': 'Groceries',
          'items': <Object?>[
            'not-a-map',
          ],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ShoppingList.fromJson(<String, dynamic>{
          'id': 'list-1',
          'name': 'Groceries',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'same',
              'name': 'Milk',
              'isCompleted': false,
            },
            <String, dynamic>{
              'id': 'same',
              'name': 'Bread',
              'isCompleted': false,
            },
          ],
        }),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('JSON field ordering is deterministic', () {
      final list = _list(items: <ShoppingItem>[_item(quantity: '2')]);
      final first = jsonEncode(list.toJson());
      final second = jsonEncode(
        ShoppingList.fromJson(list.toJson()).toJson(),
      );

      expect(first, second);
    });
  });

  group('LocalShoppingRepository', () {
    test('save and getById persist one aggregate', () async {
      final repository = LocalShoppingRepository();
      final list = _list(items: <ShoppingItem>[
        _item(quantity: '2 boxes', isCompleted: true),
      ]);

      await repository.save(list);

      expect((await repository.getById('list-1'))?.toJson(), list.toJson());
    });

    test('list returns deterministic ID ordering', () async {
      final repository = LocalShoppingRepository();
      await repository.save(_list(id: 'z', name: 'Zeta'));
      await repository.save(_list(id: 'a', name: 'Alpha'));

      expect((await repository.list()).map((item) => item.id), ['a', 'z']);
    });

    test('save replaces an existing aggregate instead of duplicating it', () async {
      final repository = LocalShoppingRepository();
      await repository.save(_list(items: <ShoppingItem>[_item()]));
      await repository.save(
        _list(name: 'Updated', items: <ShoppingItem>[_item(name: 'Bread')]),
      );

      final lists = await repository.list();
      expect(lists.length, 1);
      expect(lists.single.name, 'Updated');
      expect(lists.single.items.single.name, 'Bread');
    });

    test('delete removes only the requested aggregate', () async {
      final repository = LocalShoppingRepository();
      await repository.save(_list(id: 'a', name: 'A'));
      await repository.save(_list(id: 'b', name: 'B'));

      await repository.deleteById('a');

      expect((await repository.list()).map((item) => item.id), ['b']);
    });

    test('delete of a non-existing ID does not corrupt storage', () async {
      final repository = LocalShoppingRepository();
      await repository.save(_list(id: 'a', name: 'A'));

      await repository.deleteById('missing');

      expect((await repository.list()).map((item) => item.id), ['a']);
    });

    test('repository reload preserves aggregate data and item order', () async {
      final firstRepository = LocalShoppingRepository();
      final original = _list(items: <ShoppingItem>[
        _item(id: '2', name: 'Bread', quantity: '1 loaf'),
        _item(id: '1', name: 'Milk', isCompleted: true),
      ]);

      await firstRepository.save(original);
      final secondRepository = LocalShoppingRepository();

      expect((await secondRepository.getById(original.id))?.toJson(), original.toJson());
    });

    test('malformed root JSON returns an empty collection', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalShoppingRepository.storageKey, '{bad-json');

      expect(await LocalShoppingRepository().list(), isEmpty);
    });

    test('malformed root shape returns an empty collection', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalShoppingRepository.storageKey,
        jsonEncode(_storedLists(<Map<String, dynamic>>[])),
      );

      expect(await LocalShoppingRepository().list(), isEmpty);
    });

    test('one malformed persisted list does not erase a valid list', () async {
      final prefs = await SharedPreferences.getInstance();
      final valid = _list(id: 'valid', name: 'Valid').toJson();
      await prefs.setString(
        LocalShoppingRepository.storageKey,
        jsonEncode(<Map<String, dynamic>>[
          valid,
          <String, dynamic>{'id': 'broken', 'name': 'Broken', 'items': 'bad'},
        ]),
      );

      final lists = await LocalShoppingRepository().list();

      expect(lists.map((item) => item.id), ['valid']);
    });

    test('duplicate persisted list IDs keep the first valid record', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalShoppingRepository.storageKey,
        jsonEncode(<Map<String, dynamic>>[
          _list(id: 'same', name: 'First').toJson(),
          _list(id: 'same', name: 'Second').toJson(),
        ]),
      );

      final lists = await LocalShoppingRepository().list();

      expect(lists.length, 1);
      expect(lists.single.name, 'First');
    });

    test('shopping storage key is isolated from appointment and medication keys', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LocalAppointmentRepository.storageKey, 'appointment-sentinel');
      await prefs.setString(LocalMedicationRepository.storageKey, 'medication-sentinel');

      await LocalShoppingRepository().save(_list());

      expect(
        prefs.getString(LocalAppointmentRepository.storageKey),
        'appointment-sentinel',
      );
      expect(
        prefs.getString(LocalMedicationRepository.storageKey),
        'medication-sentinel',
      );
      expect(
        prefs.getString(LocalShoppingRepository.storageKey),
        isNotNull,
      );
    });

    test('shopping storage key is exactly dedicated and non-colliding', () {
      expect(LocalShoppingRepository.storageKey, 'nus.shopping.v1');
      expect(LocalShoppingRepository.storageKey, isNot('nus.schedule.v1'));
      expect(LocalShoppingRepository.storageKey, isNot('nus.appointments.v1'));
      expect(LocalShoppingRepository.storageKey, isNot('nus.medications.v1'));
    });
  });
}
