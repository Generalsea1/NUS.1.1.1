import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/features/expenses/domain/money.dart';
import '../lib/features/finance/application/financial_goal_service.dart';
import '../lib/features/finance/data/local_financial_goal_repository.dart';
import '../lib/features/finance/domain/financial_goal.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FinancialGoal goal({
    String id = 'goal-1',
    String userId = 'user-1',
    String name = 'طوارئ',
    int target = 10000,
    String currency = 'EGP',
    int? current = 2500,
    DateTime? targetDate,
    FinancialGoalStatus status = FinancialGoalStatus.active,
  }) {
    return FinancialGoal(
      id: id,
      userId: userId,
      name: name,
      targetAmount: Money(minorUnits: target, currencyCode: currency),
      currentAmount: current == null ? null : Money(minorUnits: current, currencyCode: currency),
      targetDate: targetDate,
      status: status,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
  }

  test('creates a goal with exact integer money and optional current amount', () {
    final item = goal(target: 12345, current: 678);
    expect(item.targetAmount.minorUnits, 12345);
    expect(item.currentAmount!.minorUnits, 678);
    expect(item.targetAmount.currencyCode, 'EGP');
  });

  test('rejects zero target', () {
    expect(() => goal(target: 0), throwsA(isA<ArgumentError>()));
  });

  test('rejects negative target', () {
    expect(() => goal(target: -1), throwsA(isA<ArgumentError>()));
  });

  test('rejects negative current amount', () {
    expect(() => goal(current: -1), throwsA(isA<ArgumentError>()));
  });

  test('rejects current amount with a different currency', () {
    expect(
      () => FinancialGoal(
        id: 'goal-1',
        userId: 'user-1',
        name: 'سفر',
        targetAmount: Money(minorUnits: 10000, currencyCode: 'EGP'),
        currentAmount: Money(minorUnits: 5000, currencyCode: 'USD'),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('progress is unavailable when current amount is missing', () {
    final item = goal(current: null);
    expect(item.progressPercent, isNull);
    expect(item.remainingAmount, isNull);
  });

  test('zero current produces zero progress and full remaining amount', () {
    final item = goal(current: 0);
    expect(item.progressPercent, 0);
    expect(item.remainingAmount!.minorUnits, 10000);
  });

  test('progress and remaining amount are exact integer results', () {
    final item = goal(target: 10000, current: 3333);
    expect(item.progressPercent, 33);
    expect(item.remainingAmount!.minorUnits, 6667);
  });

  test('target completion is deterministic', () {
    final item = goal(current: 10000);
    expect(item.isCompleted, isTrue);
    expect(item.status, FinancialGoalStatus.completed);
    expect(item.progressPercent, 100);
    expect(item.remainingAmount!.minorUnits, 0);
  });

  test('target date is stored as date only', () {
    final item = goal(targetDate: DateTime(2026, 9, 17, 18, 30));
    expect(item.targetDate, DateTime.utc(2026, 9, 17));
  });

  test('days remaining are deterministic for a supplied day', () {
    final item = goal(targetDate: DateTime.utc(2026, 9, 17));
    expect(item.daysRemaining(today: DateTime.utc(2026, 9, 7)), 10);
  });

  test('required daily saving rounds upward using integer arithmetic', () {
    final item = goal(target: 10000, current: 2500, targetDate: DateTime.utc(2026, 9, 17));
    expect(item.requiredDailySaving(today: DateTime.utc(2026, 9, 7))!.minorUnits, 750);
  });

  test('required daily saving is unavailable without current amount', () {
    final item = goal(current: null, targetDate: DateTime.utc(2026, 9, 17));
    expect(item.requiredDailySaving(today: DateTime.utc(2026, 9, 7)), isNull);
  });

  test('required daily saving is unavailable after the target date', () {
    final item = goal(targetDate: DateTime.utc(2026, 9, 1));
    expect(item.daysRemaining(today: DateTime.utc(2026, 9, 7)), -6);
    expect(item.requiredDailySaving(today: DateTime.utc(2026, 9, 7)), isNull);
  });

  test('JSON round trip preserves planning data exactly', () {
    final original = goal(target: 123456, current: 7000, targetDate: DateTime.utc(2027, 1, 5));
    final restored = FinancialGoal.fromJson(original.toJson());
    expect(restored.id, original.id);
    expect(restored.userId, original.userId);
    expect(restored.name, original.name);
    expect(restored.targetAmount, original.targetAmount);
    expect(restored.currentAmount, original.currentAmount);
    expect(restored.targetDate, original.targetDate);
    expect(restored.status, original.status);
  });

  test('repository creates and reloads persisted goals', () async {
    final repository = LocalFinancialGoalRepository();
    final item = goal();
    await repository.save('user-1', item);
    final reloaded = await repository.list('user-1');
    expect(reloaded, hasLength(1));
    expect(reloaded.single.toJson(), item.toJson());
  });

  test('repository replaces an existing goal by id for the same owner', () async {
    final repository = LocalFinancialGoalRepository();
    await repository.save('user-1', goal());
    final changed = goal(name: 'بيت', current: 5000);
    await repository.save('user-1', changed);
    final goals = await repository.list('user-1');
    expect(goals, hasLength(1));
    expect(goals.single.name, 'بيت');
    expect(goals.single.currentAmount!.minorUnits, 5000);
  });

  test('repository isolates ownership between users', () async {
    final repository = LocalFinancialGoalRepository();
    await repository.save('user-1', goal(id: 'shared-id', userId: 'user-1'));
    await repository.save('user-2', goal(id: 'shared-id', userId: 'user-2', name: 'سيارة'));
    expect((await repository.list('user-1')).single.name, 'طوارئ');
    expect((await repository.list('user-2')).single.name, 'سيارة');
    expect(await repository.getById('user-2', 'shared-id'), isNotNull);
    expect(await repository.getById('user-1', 'missing'), isNull);
  });

  test('repository rejects cross-owner mutation', () async {
    final repository = LocalFinancialGoalRepository();
    expect(
      () => repository.save('user-2', goal(userId: 'user-1')),
      throwsA(isA<StateError>()),
    );
  });

  test('service supports edit, pause, resume, and delete', () async {
    final service = FinancialGoalService(repository: LocalFinancialGoalRepository());
    final created = await service.create(
      userId: 'user-1',
      name: 'مصاريف جامعة',
      targetMinorUnits: 50000,
      targetCurrencyCode: 'EGP',
      currentMinorUnits: 10000,
    );
    expect(created.id, isNotEmpty);
    final edited = await service.update(created.copyWith(name: 'جامعة'));
    expect(edited.name, 'جامعة');
    final paused = await service.pause('user-1', created.id);
    expect(paused.status, FinancialGoalStatus.paused);
    final resumed = await service.resume('user-1', created.id);
    expect(resumed.status, FinancialGoalStatus.active);
    await service.delete('user-1', created.id);
    expect(await service.get('user-1', created.id), isNull);
  });

  test('service never exposes another user goal', () async {
    final service = FinancialGoalService(repository: LocalFinancialGoalRepository());
    await service.create(
      userId: 'user-1',
      name: 'خاص',
      targetMinorUnits: 1000,
      targetCurrencyCode: 'EGP',
    );
    expect(await service.list('user-2'), isEmpty);
  });

  test('different currencies stay separated inside their own goals', () async {
    final repository = LocalFinancialGoalRepository();
    await repository.save('user-1', goal(id: 'egp', target: 10000, currency: 'EGP'));
    await repository.save('user-1', goal(id: 'usd', target: 10000, currency: 'USD'));
    final goals = await repository.list('user-1');
    expect(goals.map((item) => item.targetAmount.currencyCode), containsAll(<String>['EGP', 'USD']));
    expect(goals[0].remainingAmount!.currencyCode, goals[0].targetAmount.currencyCode);
    expect(goals[1].remainingAmount!.currencyCode, goals[1].targetAmount.currencyCode);
  });
}
