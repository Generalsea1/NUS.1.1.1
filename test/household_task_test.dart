import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:nus/features/household/application/household_task_repository.dart';
import 'package:nus/features/household/application/household_task_service.dart';
import 'package:nus/features/household/domain/household_task.dart';
import 'package:nus/features/household/domain/household.dart';
import 'package:nus/features/household/presentation/household_tasks_page.dart';

class _FakeTaskRepository implements HouseholdTaskRepository {
  _FakeTaskRepository()
      : tasks = <HouseholdTask>[];

  List<HouseholdTask> tasks;
  var nextId = 1;

  @override
  Future<List<HouseholdTask>> list(String householdId) async =>
      tasks.where((task) => task.householdId == householdId).toList(growable: false);

  @override
  Future<HouseholdTask> create(HouseholdTask task) async {
    final created = HouseholdTask(
      id: 'task-${nextId++}',
      householdId: task.householdId,
      createdBy: task.createdBy,
      title: task.title,
      completed: task.completed,
      dueAt: task.dueAt,
    );
    tasks = [...tasks, created];
    return created;
  }

  @override
  Future<HouseholdTask> update(HouseholdTask task) async {
    tasks = [for (final current in tasks) if (current.id == task.id) task else current];
    return task;
  }

  @override
  Future<void> delete(String householdId, String taskId) async {
    tasks = tasks.where((task) => !(task.householdId == householdId && task.id == taskId)).toList(growable: false);
  }
}

void main() {
  test('task validation and completion state are deterministic', () async {
    final repository = _FakeTaskRepository();
    final service = HouseholdTaskService(repository: repository);
    final created = await service.create(
      householdId: 'h1',
      createdBy: 'u1',
      title: 'دفع فاتورة',
    );

    expect(created.completed, isFalse);
    final completed = await service.setCompleted(created, true);
    expect(completed.completed, isTrue);
    expect(completed.completedAt, isNotNull);
  });

  testWidgets('shared task page renders and creates a task', (tester) async {
    final repository = _FakeTaskRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdTasksPage(
          household: const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة'),
          currentMembership: const HouseholdMember(
            householdId: 'h1',
            userId: 'u1',
            role: 'owner',
            status: 'active',
          ),
          service: HouseholdTaskService(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('household-task-add')), findsOneWidget);
    expect(find.text('مفيش مهام مشتركة لسه. أضف أول مهمة للبيت.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('household-task-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'غسيل العربية');
    await tester.tap(find.text('إضافة').last);
    await tester.pumpAndSettle();

    expect(find.text('غسيل العربية'), findsOneWidget);
    expect(repository.tasks, hasLength(1));
  });
}
