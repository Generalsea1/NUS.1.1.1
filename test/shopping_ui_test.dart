import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/shopping/application/shopping_lifecycle_service.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';
import 'package:nus/features/shopping/domain/shopping_list.dart';
import 'package:nus/features/shopping/domain/shopping_item.dart';
import 'package:nus/features/shopping/presentation/shopping_list_details_page.dart';
import 'package:nus/features/shopping/presentation/shopping_list_editor_page.dart';
import 'package:nus/features/shopping/presentation/shopping_page.dart';

class _MemoryShoppingRepository implements ShoppingRepository {
  final Map<String, ShoppingList> data = <String, ShoppingList>{};
  bool failList = false;
  bool failSave = false;
  bool failDelete = false;
  final Completer<List<ShoppingList>>? listCompleter;

  _MemoryShoppingRepository({this.listCompleter});

  @override
  Future<ShoppingList?> getById(String id) async {
    return data[id];
  }

  @override
  Future<List<ShoppingList>> list() async {
    if (listCompleter != null) return listCompleter!.future;
    if (failList) throw StateError('list failed');
    final lists = data.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return lists;
  }

  @override
  Future<void> save(ShoppingList entity) async {
    if (failSave) throw StateError('save failed');
    data[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    if (failDelete) throw StateError('delete failed');
    data.remove(id);
  }
}

ShoppingList _list(String id, String name, {List<ShoppingItem> items = const <ShoppingItem>[]}) =>
    ShoppingList(id: id, name: name, items: items);

ShoppingLifecycleService _service(ShoppingRepository repository) =>
    ShoppingLifecycleService(repository: repository);

Future<void> _pumpPage(WidgetTester tester, ShoppingLifecycleService service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ShoppingPage(service: service),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> _saveListEditor(WidgetTester tester) async {
  final finder = find.byKey(const Key('shopping_list_editor_save'), skipOffstage: false);
  expect(finder, findsOneWidget);
  await _hideKeyboard(tester);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _saveItemEditor(WidgetTester tester) async {
  final finder = find.byKey(const Key('shopping_item_editor_save'), skipOffstage: false);
  expect(finder, findsOneWidget);
  await _hideKeyboard(tester);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _createListFromUi(WidgetTester tester, String name) async {
  await tester.tap(find.text('قائمة جديدة'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('shopping_list_name_field')), name);
  await _saveListEditor(tester);
}

Future<void> _openList(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _addItemFromUi(WidgetTester tester, String name, {String? quantity}) async {
  await tester.tap(find.text('إضافة عنصر').first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('shopping_item_name_field')), name);
  if (quantity != null) {
    await tester.enterText(find.byKey(const Key('shopping_item_quantity_field')), quantity);
  }
  await _saveItemEditor(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Shopping page loads', (tester) async {
    final repository = _MemoryShoppingRepository();
    await _pumpPage(tester, _service(repository));

    expect(find.text('المشتريات'), findsOneWidget);
  });

  testWidgets('empty state appears when no lists exist', (tester) async {
    await _pumpPage(tester, _service(_MemoryShoppingRepository()));

    expect(find.text('لسه مفيش قوائم مشتريات'), findsOneWidget);
    expect(find.text('إنشاء قائمة'), findsOneWidget);
  });

  testWidgets('existing lists appear', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    await _pumpPage(tester, _service(repository));

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('لسه مفيش قوائم مشتريات'), findsNothing);
  });

  testWidgets('create list', (tester) async {
    final repository = _MemoryShoppingRepository();
    final service = _service(repository);
    await _pumpPage(tester, service);

    await _createListFromUi(tester, 'Weekend groceries');

    expect(find.text('Weekend groceries'), findsOneWidget);
    expect((await service.getAllLists()).single.name, 'Weekend groceries');
  });

  testWidgets('validation rejects empty list name', (tester) async {
    await _pumpPage(tester, _service(_MemoryShoppingRepository()));

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await _saveListEditor(tester);

    expect(find.text('اسم القائمة مطلوب.'), findsOneWidget);
    expect(find.byType(ShoppingListEditorPage), findsOneWidget);
  });

  testWidgets('edit list', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Old name');
    await _pumpPage(tester, _service(repository));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'New name');
    await _saveListEditor(tester);

    expect(find.text('New name'), findsOneWidget);
    expect((await _service(repository).getList('l1'))!.name, 'New name');
  });

  testWidgets('delete list requires confirmation and removes only that list', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'First')
      ..data['l2'] = _list('l2', 'Second');
    await _pumpPage(tester, _service(repository));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    expect(find.text('تحذف قائمة المشتريات؟'), findsOneWidget);
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(repository.data.containsKey('l1'), isFalse);
    expect(repository.data.containsKey('l2'), isTrue);
  });

  testWidgets('open list details', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    await _pumpPage(tester, _service(repository));

    await _openList(tester, 'Groceries');

    expect(find.byType(ShoppingListDetailsPage), findsOneWidget);
    expect(find.text('لسه مفيش عناصر'), findsOneWidget);
  });

  testWidgets('empty item state', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    await _pumpPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    expect(find.text('لسه مفيش عناصر'), findsOneWidget);
    expect(find.text('إضافة عنصر'), findsWidgets);
  });

  testWidgets('add item', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    final service = _service(repository);
    await _pumpPage(tester, service);
    await _openList(tester, 'Groceries');

    await _addItemFromUi(tester, 'Milk', quantity: '2 cartons');

    final list = await service.getList('l1');
    expect(list!.items.single.name, 'Milk');
    expect(list.items.single.quantity, '2 cartons');
    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('validation rejects empty item name', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    await _pumpPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    await tester.tap(find.text('إضافة عنصر').first);
    await tester.pumpAndSettle();
    await _saveItemEditor(tester);

    expect(find.text('اسم العنصر مطلوب.'), findsOneWidget);
    expect(find.byKey(const Key('shopping_item_editor_save')), findsOneWidget);
  });

  testWidgets('edit item', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list(
        'l1',
        'Groceries',
        items: const [ShoppingItem(id: 'i1', name: 'Milk')],
      );
    final service = _service(repository);
    await _pumpPage(tester, service);
    await _openList(tester, 'Groceries');

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Oat milk');
    await tester.enterText(find.byKey(const Key('shopping_item_quantity_field')), '1 bottle');
    await _saveItemEditor(tester);

    final item = (await service.getList('l1'))!.items.single;
    expect(item.name, 'Oat milk');
    expect(item.quantity, '1 bottle');
    expect(item.id, 'i1');
  });

  testWidgets('toggle item completion', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list(
        'l1',
        'Groceries',
        items: const [ShoppingItem(id: 'i1', name: 'Milk')],
      );
    final service = _service(repository);
    await _pumpPage(tester, service);
    await _openList(tester, 'Groceries');

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect((await service.getList('l1'))!.items.single.isCompleted, isTrue);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect((await service.getList('l1'))!.items.single.isCompleted, isFalse);
  });

  testWidgets('remove item', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list(
        'l1',
        'Groceries',
        items: const [ShoppingItem(id: 'i1', name: 'Milk')],
      );
    await _pumpPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    expect(find.text('تحذف العنصر؟'), findsOneWidget);
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsNothing);
    expect((await _service(repository).getList('l1'))!.items, isEmpty);
  });

  testWidgets('optional quantity display', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list(
        'l1',
        'Groceries',
        items: const [ShoppingItem(id: 'i1', name: 'Apples', quantity: '3 bags')],
      );
    await _pumpPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    expect(find.text('Apples'), findsOneWidget);
    expect(find.text('3 bags'), findsOneWidget);
  });

  testWidgets('loading state appears while Shopping lists are loading', (tester) async {
    final completer = Completer<List<ShoppingList>>();
    final repository = _MemoryShoppingRepository(listCompleter: completer);
    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingPage(service: _service(repository)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(<ShoppingList>[]);
    await tester.pumpAndSettle();
    expect(find.text('لسه مفيش قوائم مشتريات'), findsOneWidget);
  });

  testWidgets('repository load error is visible', (tester) async {
    final repository = _MemoryShoppingRepository()..failList = true;
    await _pumpPage(tester, _service(repository));

    expect(find.text('تعذر تحميل قوائم المشتريات.'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });

  testWidgets('repository mutation error is visible', (tester) async {
    final repository = _MemoryShoppingRepository()..failSave = true;
    await _pumpPage(tester, _service(repository));

    await _createListFromUi(tester, 'Cannot save');

    expect(find.text('تعذر حفظ قائمة المشتريات.'), findsOneWidget);
    expect(find.text('لسه مفيش قوائم مشتريات'), findsOneWidget);
  });

  testWidgets('multiple-list isolation through UI', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'First')
      ..data['l2'] = _list('l2', 'Second');
    final service = _service(repository);
    await _pumpPage(tester, service);

    await _openList(tester, 'First');
    await _addItemFromUi(tester, 'Milk');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openList(tester, 'Second');

    expect(find.text('Milk'), findsNothing);
    expect(find.text('لسه مفيش عناصر'), findsOneWidget);
    expect((await service.getList('l1'))!.items.single.name, 'Milk');
    expect((await service.getList('l2'))!.items, isEmpty);
  });

  testWidgets('navigation between list and details', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Groceries');
    await _pumpPage(tester, _service(repository));

    await _openList(tester, 'Groceries');
    expect(find.byType(ShoppingListDetailsPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ShoppingPage), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('cancel editor preserves previous state', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Original');
    final service = _service(repository);
    await _pumpPage(tester, service);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Unsaved');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_list_editor_cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Unsaved'), findsNothing);
    expect((await service.getList('l1'))!.name, 'Original');
  });

  testWidgets('repeated edit and save does not duplicate data', (tester) async {
    final repository = _MemoryShoppingRepository()
      ..data['l1'] = _list('l1', 'Original');
    final service = _service(repository);
    await _pumpPage(tester, service);

    for (final name in <String>['First edit', 'Second edit', 'Second edit']) {
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('shopping_list_name_field')), name);
      await _saveListEditor(tester);
    }

    final lists = await service.getAllLists();
    expect(lists, hasLength(1));
    expect(lists.single.id, 'l1');
    expect(lists.single.name, 'Second edit');
  });

  testWidgets('editor dismissal is lifecycle safe and keyboard-safe', (tester) async {
    final repository = _MemoryShoppingRepository();
    final service = _service(repository);
    await _pumpPage(tester, service);

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Keyboard safe');
    await _hideKeyboard(tester);
    await tester.ensureVisible(find.byKey(const Key('shopping_list_editor_save')));
    await tester.tap(find.byKey(const Key('shopping_list_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('Keyboard safe'), findsOneWidget);
    expect((await service.getAllLists()).single.name, 'Keyboard safe');
  });

  testWidgets('UI mutation persists through LocalShoppingRepository and a new service instance', (tester) async {
    final repository = LocalShoppingRepository();
    final service = _service(repository);
    await _pumpPage(tester, service);

    await _createListFromUi(tester, 'Persisted list');
    await _openList(tester, 'Persisted list');
    await _addItemFromUi(tester, 'Persisted item', quantity: '4');

    final freshRepository = LocalShoppingRepository();
    final freshService = _service(freshRepository);
    final lists = await freshService.getAllLists();

    expect(lists, hasLength(1));
    expect(lists.single.name, 'Persisted list');
    expect(lists.single.items.single.name, 'Persisted item');
    expect(lists.single.items.single.quantity, '4');
  });
}
