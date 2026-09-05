import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/bills/application/subscription_mutation_service.dart';
import 'package:nus/features/bills/domain/subscription.dart';

class _FakeSubscriptionRepository implements SubscriptionRepository {
  final Map<String, Subscription> values = {};

  @override
  Future<Subscription?> getById(String id) async => values[id.trim()];

  @override
  Future<List<Subscription>> list() async => values.values.toList();

  @override
  Future<void> save(Subscription entity) async => values[entity.id] = entity;

  @override
  Future<void> deleteById(String id) async => values.remove(id.trim());
}

void main() {
  final dueAt = DateTime.utc(2026, 9, 30, 12);

  test('creates through repository and rejects duplicate IDs', () async {
    final repository = _FakeSubscriptionRepository();
    final service = SubscriptionMutationService(subscriptions: repository);

    final created = await service.create(
      id: 'sub-1',
      title: 'Streaming',
      amountMinorUnits: 1299,
      currencyCode: 'usd',
      cadence: SubscriptionCadence.monthly,
      nextDueAt: dueAt,
    );

    expect(created.currencyCode, 'USD');
    expect(repository.values['sub-1'], created);
    expect(
      () => service.create(
        id: 'sub-1',
        title: 'Duplicate',
        amountMinorUnits: 100,
        currencyCode: 'USD',
        cadence: SubscriptionCadence.monthly,
        nextDueAt: dueAt,
      ),
      throwsStateError,
    );
  });

  test('updates only an existing subscription', () async {
    final repository = _FakeSubscriptionRepository();
    final service = SubscriptionMutationService(subscriptions: repository);
    final original = Subscription(
      id: 'sub-1',
      title: 'Streaming',
      amountMinorUnits: 1299,
      currencyCode: 'USD',
      cadence: SubscriptionCadence.monthly,
      nextDueAt: dueAt,
    );
    await repository.save(original);

    final updated = original.copyWith(amountMinorUnits: 1499);
    await service.update(updated);
    expect(repository.values['sub-1']!.amountMinorUnits, 1499);

    final unknown = original.copyWith(id: 'missing');
    expect(() => service.update(unknown), throwsStateError);
  });

  test('archives and unarchives without changing identity', () async {
    final repository = _FakeSubscriptionRepository();
    final service = SubscriptionMutationService(subscriptions: repository);
    await service.create(
      id: 'sub-1',
      title: 'Streaming',
      amountMinorUnits: 1299,
      currencyCode: 'USD',
      cadence: SubscriptionCadence.monthly,
      nextDueAt: dueAt,
    );

    final archived = await service.archive('sub-1');
    expect(archived.isArchived, isTrue);
    expect(archived.id, 'sub-1');

    final active = await service.unarchive('sub-1');
    expect(active.isArchived, isFalse);
    expect(active.id, 'sub-1');
  });
}
