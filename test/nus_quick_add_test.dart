import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/expenses/application/expense_management_service.dart';
import 'package:nus/features/expenses/domain/expense.dart';
import 'package:nus/features/expenses/domain/money.dart';
import 'package:nus/features/expenses/domain/recurring_expense_definition.dart';
import 'package:nus/features/shopping/application/shopping_lifecycle_service.dart';
import 'package:nus/features/shopping/domain/shopping_list.dart';
import 'package:nus/features/today/presentation/nus_quick_add_page.dart';

class _FakeExpenseRepository implements ExpenseRepository {
  final List<Expense> saved = <Expense>[];

  @override
  Future<Expense?> getById(String id) async {
    for (final expense in saved) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<List<Expense>> list() async => List<Expense>.of(saved);

  @override
  Future<void> save(Expense entity) async {
    saved.removeWhere((expense) => expense.id == entity.id);
    saved.add(entity);
  }

  @override
  Future<void> deleteById(String id) async {
    saved.removeWhere((expense) => expense.id == id);
  }
}

class _FakeRecurringRepository implements RecurringExpenseRepository {
  @override
  Future<RecurringExpenseDefinition?> getById(String id) async => null;

  @override
  Future<List<RecurringExpenseDefinition>> list() async => const <RecurringExpenseDefinition>[];

  @override
  Future<void> save(RecurringExpenseDefinition entity) async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<RecurringExpenseDefinition> setEnabled(
    String userId,
    String id,
    bool enabled,
  ) => throw UnimplementedError();
}

class _FakeShoppingRepository implements ShoppingRepository {
  final List<ShoppingList> saved = <ShoppingList>[];

  @override
  Future<ShoppingList?> getById(String id) async {
    for (final list in saved) {
      if (list.id == id) return list;
    }
    return null;
  }

  @override
  Future<List<ShoppingList>> list() async => List<ShoppingList>.of(saved);

  @override
  Future<void> save(ShoppingList entity) async {
    saved.removeWhere((list) => list.id == entity.id);
    saved.add(entity);
  }

  @override
  Future<void> deleteById(String id) async {
    saved.removeWhere((list) => list.id == id);
  }
}

void main() {
  testWidgets('quick add exposes fast time shortcuts and preserves selection', (tester) async {
    DateTime? savedAt;
    String? savedTitle;

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (title, dateTime) async {
            savedTitle = title;
            savedAt = dateTime;
          },
        ),
      ),
    );

    expect(find.text('بعد ساعة'), findsOneWidget);
    expect(find.text('بكرة 9 صباحًا'), findsOneWidget);
    expect(find.text('بكرة 6 مساءً'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'دفع الكهرباء');
    await tester.tap(find.text('بكرة 9 صباحًا'));
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pumpAndSettle();

    expect(savedTitle, 'دفع الكهرباء');
    expect(savedAt, isNotNull);
    expect(savedAt!.hour, 9);
  });

  testWidgets('quick add confirms and persists an expense through the financial boundary', (tester) async {
    final expenseRepository = _FakeExpenseRepository();
    final expenseService = ExpenseManagementService(
      expenseRepository: expenseRepository,
      recurringRepository: _FakeRecurringRepository(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (_, __) async {},
          expenseManagementService: expenseService,
          userId: 'user-1',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'دفعت 350 جنيه مواصلات');
    await tester.pump();

    expect(find.text('NUS فهمها كـ مصروف'), findsOneWidget);
    expect(find.textContaining('350 EGP'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pumpAndSettle();

    expect(find.text('تأكيد تسجيل المصروف'), findsOneWidget);
    expect(find.text('350 EGP'), findsOneWidget);

    await tester.tap(find.text('تأكيد الحفظ'));
    await tester.pumpAndSettle();

    expect(expenseRepository.saved, hasLength(1));
    expect(expenseRepository.saved.single.amount, Money(minorUnits: 35000, currencyCode: 'EGP'));
    expect(expenseRepository.saved.single.categoryCode, 'transportation');
    expect(expenseRepository.saved.single.userId, 'user-1');
  });

  testWidgets('quick add executes shopping items into the canonical shopping list', (tester) async {
    final shoppingRepository = _FakeShoppingRepository();
    final shoppingService = ShoppingLifecycleService(repository: shoppingRepository);

    await tester.pumpWidget(
      MaterialApp(
        home: NusQuickAddPage(
          onCreateReminder: (_, __) async {},
          shoppingService: shoppingService,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'هات لبن وبيض وعيش');
    await tester.pump();

    expect(find.text('NUS فهمها كـ مشتريات'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -1100));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-save')));
    await tester.pumpAndSettle();

    expect(shoppingRepository.saved, hasLength(1));
    final items = shoppingRepository.saved.single.items;
    expect(items.map((item) => item.name), containsAll(<String>['لبن', 'بيض', 'عيش']));
  });
}
