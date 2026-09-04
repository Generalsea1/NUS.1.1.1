import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/shopping/application/shopping_lifecycle_service.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';
import 'package:nus/features/shopping/domain/shopping_item.dart';
import 'package:nus/features/shopping/domain/shopping_list.dart';

class _FakeShoppingRepository implements ShoppingRepository {
  final Map<String, ShoppingList> _store = <String, ShoppingList>{};
  int saveCount = 0;
  int deleteCount = 0;
  bool failSave = false;

  @override
  Future<ShoppingList?> getById(String id) async => _store[id];

  @override
  Future<List<ShoppingList>> list() async => List<ShoppingList>.of(_store.values);

  @override
  Future<void> save(ShoppingList entity) async {
    saveCount++;
    if (failSave) throw StateError('repository failed');
    _store[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    deleteCount++;
    _store.remove(id);
  }
}

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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('ShoppingLifecycleService', () {
    test('creates and persists a shopping list with an opaque ID', () async {
      final repository = _FakeShoppingRepository();
      final service = ShoppingLifecycleService(repository: repository);

      final created = await service.createList(name: 'Groceries');

      expect(created.name, 'Groceries');
      expect(created.id, startsWith('sl-'));
      expect(created.id, isNot(contains('Groceries')));
      expect(await repository.getById(created.id), same(created));
    });

    test('retrieves a shopping list by ID', () async {
      final repository = _FakeShoppingRepository();
      final stored = _list();
      await repository.save(stored);
      final service = ShoppingLifecycleService(repository: repository);

      expect((await service.getList(stored.id))?.toJson(), stored.toJson());
    });

    test('retrieves all shopping lists through the repository', () async {
      final repository = _FakeShoppingRepository();
      final first = _list(id: 'a', name: 'A');
      final second = _list(id: 'b', name: 'B');
      await repository.save(first);
      await repository.save(second);
      final service = ShoppingLifecycleService(repository: repository);

      expect(
        (await service.getAllLists()).map((item) => item.id).toSet(),
        {'a', 'b'},
      );
    });

    test('updates a list while preserving its identity', () async {
      final repository = _FakeShoppingRepository();
      final original = _list();
      await repository.save(original);
      final service = ShoppingLifecycleService(repository: repository);

      final updated = await service.updateList(original.id, name: 'Weekly Shop');

      expect(updated.id, original.id);
      expect(updated.name, 'Weekly Shop');
      expect((await repository.getById(original.id))?.name, 'Weekly Shop');
    });

    test('deletes only the requested list', () async {
      final repository = _FakeShoppingRepository();
      await repository.save(_list(id: 'a', name: 'A'));
      await repository.save(_list(id: 'b', name: 'B'));
      final service = ShoppingLifecycleService(repository: repository);

      await service.deleteList('a');

      expect(await service.getList('a'), isNull);
      expect((await service.getList('b'))?.name, 'B');
    });

    test('adds a generated-ID item through the aggregate and saves it', () async {
      final repository = _FakeShoppingRepository();
      final list = _list();
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      final updated = await service.addItem(
        list.id,
        name: 'Milk',
        quantity: '2 cartons',
      );

      expect(updated.items, hasLength(1));
      expect(updated.items.single.name, 'Milk');
      expect(updated.items.single.quantity, '2 cartons');
      expect(updated.items.single.id, startsWith('si-'));
      expect(updated.items.single.id, isNot(contains('Milk')));
      expect(repository.saveCount, 2);
    });

    test('updates an existing item through the aggregate', () async {
      final repository = _FakeShoppingRepository();
      final list = _list(items: <ShoppingItem>[_item(quantity: '1')]);
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      final updated = await service.updateItem(
        list.id,
        _item(quantity: '3', isCompleted: true),
      );

      expect(updated.items.single.id, 'item-1');
      expect(updated.items.single.quantity, '3');
      expect(updated.items.single.isCompleted, isTrue);
    });

    test('removes an item through the aggregate and persists the replacement', () async {
      final repository = _FakeShoppingRepository();
      final list = _list(items: <ShoppingItem>[
        _item(id: 'item-1', name: 'Milk'),
        _item(id: 'item-2', name: 'Bread'),
      ]);
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      final updated = await service.removeItem(list.id, 'item-1');

      expect(updated.items.map((item) => item.id), ['item-2']);
      expect((await repository.getById(list.id))?.items.map((item) => item.id), ['item-2']);
    });

    test('sets item completion through the aggregate', () async {
      final repository = _FakeShoppingRepository();
      final list = _list(items: <ShoppingItem>[_item()]);
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      final updated = await service.setItemCompleted(list.id, 'item-1', true);

      expect(updated.items.single.isCompleted, isTrue);
    });

    test('toggles item completion through the aggregate', () async {
      final repository = _FakeShoppingRepository();
      final list = _list(items: <ShoppingItem>[_item(isCompleted: false)]);
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      final first = await service.toggleItemCompletion(list.id, 'item-1');
      final second = await service.toggleItemCompletion(list.id, 'item-1');

      expect(first.items.single.isCompleted, isTrue);
      expect(second.items.single.isCompleted, isFalse);
    });

    test('get by ID returns null for a missing list', () async {
      final service = ShoppingLifecycleService(repository: _FakeShoppingRepository());

      expect(await service.getList('missing'), isNull);
    });

    test('mutation of a missing list fails explicitly', () async {
      final service = ShoppingLifecycleService(repository: _FakeShoppingRepository());

      expect(
        () => service.updateList('missing', name: 'Updated'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => service.deleteList('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('missing item behavior comes from the aggregate for item updates', () async {
      final repository = _FakeShoppingRepository();
      final list = _list();
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);

      expect(
        () => service.updateItem(list.id, _item(id: 'missing')),
        throwsA(isA<StateError>()),
      );
      expect(
        () => service.setItemCompleted(list.id, 'missing', true),
        throwsA(isA<StateError>()),
      );
      expect(
        () => service.toggleItemCompletion(list.id, 'missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid list input fails before repository save', () async {
      final repository = _FakeShoppingRepository();
      final service = ShoppingLifecycleService(repository: repository);

      expect(
        () => service.createList(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.saveCount, 0);
    });

    test('invalid item input fails before repository save', () async {
      final repository = _FakeShoppingRepository();
      final list = _list();
      await repository.save(list);
      final service = ShoppingLifecycleService(repository: repository);
      final savesBeforeMutation = repository.saveCount;

      expect(
        () => service.addItem(list.id, name: '   '),
        throwsA(isA<ArgumentError>()),
      );
      expect(repository.saveCount, savesBeforeMutation);
    });

    test('different lists remain isolated even with identically named items', () async {
      final repository = _FakeShoppingRepository();
      final first = _list(
        id: 'list-a',
        name: 'A',
        items: <ShoppingItem>[_item(id: 'same-item', name: 'Milk')],
      );
      final second = _list(
        id: 'list-b',
        name: 'B',
        items: <ShoppingItem>[_item(id: 'same-item', name: 'Milk')],
      );
      await repository.save(first);
      await repository.save(second);
      final service = ShoppingLifecycleService(repository: repository);

      await service.updateItem('list-a', _item(id: 'same-item', name: 'Bread'));
      await service.deleteList('list-a');

      expect(await service.getList('list-a'), isNull);
      expect((await service.getList('list-b'))?.items.single.name, 'Milk');
      expect((await service.getList('list-b'))?.items.single.id, 'same-item');
    });

    test('repeated mutations persist each replacement without mutating prior snapshots', () async {
      final repository = _FakeShoppingRepository();
      final service = ShoppingLifecycleService(repository: repository);
      final original = await service.createList(name: 'Groceries');
      final afterAdd = await service.addItem(original.id, name: 'Milk');
      final item = afterAdd.items.single;
      final afterUpdate = await service.updateItem(
        original.id,
        item.copyWith(name: 'Whole milk'),
      );
      final afterComplete = await service.setItemCompleted(
        original.id,
        item.id,
        true,
      );

      expect(original.items, isEmpty);
      expect(afterAdd.items.single.name, 'Milk');
      expect(afterUpdate.items.single.name, 'Whole milk');
      expect(afterComplete.items.single.isCompleted, isTrue);
      expect(repository.saveCount, 4);
    });

    test('repository save failures propagate unchanged', () async {
      final repository = _FakeShoppingRepository()..failSave = true;
      final service = ShoppingLifecycleService(repository: repository);

      expect(
        () => service.createList(name: 'Groceries'),
        throwsA(isA<StateError>()),
      );
      expect(repository.saveCount, 1);
    });

    test('application mutation survives LocalShoppingRepository reload', () async {
      final firstRepository = LocalShoppingRepository();
      final firstService = ShoppingLifecycleService(repository: firstRepository);

      final created = await firstService.createList(name: 'Reload Me');
      final updated = await firstService.addItem(
        created.id,
        name: 'Persisted Milk',
        quantity: '2',
      );
      await firstService.setItemCompleted(
        updated.id,
        updated.items.single.id,
        true,
      );

      final secondRepository = LocalShoppingRepository();
      final secondService = ShoppingLifecycleService(repository: secondRepository);
      final reloaded = await secondService.getList(created.id);

      expect(reloaded?.id, created.id);
      expect(reloaded?.name, 'Reload Me');
      expect(reloaded?.items.single.name, 'Persisted Milk');
      expect(reloaded?.items.single.quantity, '2');
      expect(reloaded?.items.single.isCompleted, isTrue);
    });
  });
}
