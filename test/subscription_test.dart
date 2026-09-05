import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/bills/domain/subscription.dart';

void main() {
  final dueAt = DateTime.utc(2026, 9, 30, 12);

  test('normalizes currency and round-trips exact subscription data', () {
    final subscription = Subscription(
      id: ' sub-1 ',
      title: ' Streaming ',
      amountMinorUnits: 1299,
      currencyCode: 'usd',
      cadence: SubscriptionCadence.monthly,
      nextDueAt: dueAt,
    );

    expect(subscription.id, 'sub-1');
    expect(subscription.title, 'Streaming');
    expect(subscription.currencyCode, 'USD');
    expect(subscription.amountMinorUnits, 1299);
    expect(Subscription.fromJson(subscription.toJson()), subscription);
  });

  test('rejects invalid identity, money, and currency', () {
    expect(
      () => Subscription(
        id: '',
        title: 'Streaming',
        amountMinorUnits: 1299,
        currencyCode: 'USD',
        cadence: SubscriptionCadence.monthly,
        nextDueAt: dueAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => Subscription(
        id: 'sub-1',
        title: 'Streaming',
        amountMinorUnits: 0,
        currencyCode: 'USD',
        cadence: SubscriptionCadence.monthly,
        nextDueAt: dueAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => Subscription(
        id: 'sub-1',
        title: 'Streaming',
        amountMinorUnits: 1299,
        currencyCode: 'US',
        cadence: SubscriptionCadence.monthly,
        nextDueAt: dueAt,
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-integer money and unknown cadence from JSON', () {
    final json = <String, dynamic>{
      'id': 'sub-1',
      'title': 'Streaming',
      'amountMinorUnits': 12.5,
      'currencyCode': 'USD',
      'cadence': 'monthly',
      'nextDueAt': dueAt.toIso8601String(),
      'isArchived': false,
    };
    expect(() => Subscription.fromJson(json), throwsFormatException);

    final invalidCadence = <String, dynamic>{
      ...json,
      'amountMinorUnits': 1299,
      'cadence': 'everyTwoWeeks',
    };
    expect(() => Subscription.fromJson(invalidCadence), throwsFormatException);
  });

  test('archive and unarchive preserve stable identity', () {
    final subscription = Subscription(
      id: 'sub-1',
      title: 'Streaming',
      amountMinorUnits: 1299,
      currencyCode: 'USD',
      cadence: SubscriptionCadence.monthly,
      nextDueAt: dueAt,
    );

    expect(subscription.archive().isArchived, isTrue);
    expect(subscription.archive().id, subscription.id);
    expect(subscription.archive().unarchive().isArchived, isFalse);
  });
}
