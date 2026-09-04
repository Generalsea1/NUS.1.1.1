import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nus/features/shopping/application/shopping_lifecycle_service.dart';
import 'package:nus/features/shopping/data/local_shopping_repository.dart';
import 'package:nus/features/shopping/domain/shopping_item.dart';
import 'package:nus/features/shopping/domain/shopping_list.dart';
import 'package:nus/features/shopping/presentation/shopping_list_details_page.dart';
import 'package:nus/features/shopping/presentation/shopping_list_editor_page.dart';
import 'package:nus/features/shopping/presentation/shopping_page.dart';

class _HardeningRepository implements ShoppingRepository {
  final Map<String, ShoppingList> data = <String, ShoppingList>{};
  int failSaves = 0;
  Completer<void>? saveGate;

  @override
  Future<ShoppingList?> getById(String id) async => data[id];

  @override
  Future<List<ShoppingList>> list() async => List<ShoppingList>.of(data.values);

  @override
  Future<void> save(ShoppingList entity) async {
    if (failSaves > 0) {
      failSaves--;
      throw StateError('save failed');
    }
    final gate = saveGate;
    if (gate != null) await gate.future;
    data[entity.id] = entity;
  }

  @override
  Future<void> deleteById(String id) async {
    data.remove(id);
  }
}

ShoppingList _list({
  String id = 'list-1',
  String name = 'Groceries',
  List<ShoppingItem> items = const <ShoppingItem>[],
}) => ShoppingList(id: id, name: name, items: items);

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

ShoppingLifecycleService _service(ShoppingRepository repository) =>
    ShoppingLifecycleService(repository: repository);

Future<void> _pumpShoppingPage(
  WidgetTester tester,
  ShoppingLifecycleService service,
) async {
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

Future<void> _openList(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _hideKeyboard(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('list editor ignores rapid duplicate save submissions', (tester) async {
    final repository = _HardeningRepository();
    final service = _service(repository);
    await _pumpShoppingPage(tester, service);

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'One list');
    final save = find.byKey(const Key('shopping_list_editor_save'));
    await tester.tap(save, warnIfMissed: false);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect((await service.getAllLists()), hasLength(1));
    expect((await service.getAllLists()).single.name, 'One list');
  });

  testWidgets('item editor ignores rapid duplicate save submissions', (tester) async {
    final repository = _HardeningRepository()
      ..data['list-1'] = _list();
    await _pumpShoppingPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    await tester.tap(find.text('إضافة عنصر').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Milk');
    final save = find.byKey(const Key('shopping_item_editor_save'));
    await tester.tap(save, warnIfMissed: false);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repository.data['list-1']!.items, hasLength(1));
    expect(repository.data['list-1']!.items.single.name, 'Milk');
  });

  testWidgets('list mutation exposes loading state and recovers after completion', (tester) async {
    final repository = _HardeningRepository()..saveGate = Completer<void>();
    final service = _service(repository);
    await _pumpShoppingPage(tester, service);

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Blocked save');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_list_editor_save')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Blocked save'), findsNothing);

    repository.saveGate!.complete();
    repository.saveGate = null;
    await tester.pumpAndSettle();

    expect(find.text('Blocked save'), findsOneWidget);
  });

  testWidgets('item mutation exposes loading state and recovers after completion', (tester) async {
    final repository = _HardeningRepository()
      ..data['list-1'] = _list()
      ..saveGate = Completer<void>();
    await _pumpShoppingPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    await tester.tap(find.text('إضافة عنصر').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Milk');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_item_editor_save')));
    await tester.pump();

    expect(find.text('جارٍ الحفظ'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);

    repository.saveGate!.complete();
    repository.saveGate = null;
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
  });

  testWidgets('mutation failure remains visible and next attempt recovers', (tester) async {
    final repository = _HardeningRepository()..failSaves = 1;
    await _pumpShoppingPage(tester, _service(repository));

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Retry me');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_list_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('تعذر حفظ قائمة المشتريات.'), findsOneWidget);
    expect(find.text('لسه مفيش قوائم مشتريات'), findsOneWidget);

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Retry me');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_list_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('Retry me'), findsOneWidget);
  });

  testWidgets('delete list cancellation leaves the list unchanged', (tester) async {
    final repository = _HardeningRepository()
      ..data['a'] = _list(id: 'a', name: 'First')
      ..data['b'] = _list(id: 'b', name: 'Second');
    await _pumpShoppingPage(tester, _service(repository));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(repository.data, hasLength(2));
  });

  testWidgets('delete item cancellation leaves the item unchanged', (tester) async {
    final repository = _HardeningRepository()
      ..data['list-1'] = _list(items: <ShoppingItem>[_item()]);
    await _pumpShoppingPage(tester, _service(repository));
    await _openList(tester, 'Groceries');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(repository.data['list-1']!.items, hasLength(1));
  });

  testWidgets('completion survives leaving and reopening the details page', (tester) async {
    final repository = _HardeningRepository()
      ..data['list-1'] = _list(items: <ShoppingItem>[_item()]);
    final service = _service(repository);
    await _pumpShoppingPage(tester, service);
    await _openList(tester, 'Groceries');

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openList(tester, 'Groceries');

    expect((await service.getList('list-1'))!.items.single.isCompleted, isTrue);
    expect(find.byType(Checkbox).first.evaluate().single.widget, isA<Checkbox>());
  });

  testWidgets('UI mutation persists through repository recreation after rename, edit and delete', (tester) async {
    final repository = LocalShoppingRepository();
    final service = _service(repository);
    await repository.save(_list());
    await _pumpShoppingPage(tester, service);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Persisted name');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_list_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('Persisted name'), findsOneWidget);
    await _openList(tester, 'Persisted name');
    await tester.tap(find.text('إضافة عنصر').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Bread');
    await tester.enterText(find.byKey(const Key('shopping_item_quantity_field')), ' 2 loaves ');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_item_editor_save')));
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect((await service.getList('list-1'))!.items.single.quantity, ' 2 loaves ');

    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Whole wheat bread');
    await _hideKeyboard(tester);
    await tester.tap(find.byKey(const Key('shopping_item_editor_save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').last);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final reloadedRepository = LocalShoppingRepository();
    final reloadedService = _service(reloadedRepository);
    expect(await reloadedService.getList('list-1'), isNull);
  });

  testWidgets('list cancel preserves previous state and item cancel preserves previous state', (tester) async {
    final repository = _HardeningRepository()
      ..data['list-1'] = _list(items: <ShoppingItem>[_item()]);
    await _pumpShoppingPage(tester, _service(repository));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Should not persist');
    await tester.tap(find.byKey(const Key('shopping_list_editor_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);

    await _openList(tester, 'Groceries');
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_item_name_field')), 'Should not persist');
    await tester.tap(find.byKey(const Key('shopping_item_editor_cancel')));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect((await _service(repository).getList('list-1'))!.items.single.name, 'Milk');
  });

  testWidgets('keyboard-safe save completes without obscured save hitbox', (tester) async {
    final repository = _HardeningRepository();
    await _pumpShoppingPage(tester, _service(repository));

    await tester.tap(find.text('قائمة جديدة'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shopping_list_name_field')), 'Keyboard safe');
    await tester.showKeyboard(find.byKey(const Key('shopping_list_name_field')));
    await _hideKeyboard(tester);
    final save = find.byKey(const Key('shopping_list_editor_save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Keyboard safe'), findsOneWidget);
  });
}
