import '../domain/subscription.dart';

/// Controlled application boundary for subscription lifecycle mutations.
///
/// This service does not calculate future occurrences and does not create
/// expenses automatically. Those responsibilities belong to later
/// recurrence/financial integration slices.
class SubscriptionMutationService {
  const SubscriptionMutationService({required SubscriptionRepository subscriptions});

  final SubscriptionRepository subscriptions;

  Future<Subscription> create({
    required String id,
    required String title,
    required int amountMinorUnits,
    required String currencyCode,
    required SubscriptionCadence cadence,
    required DateTime nextDueAt,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id');
    if (await subscriptions.getById(cleanId) != null) {
      throw StateError('Subscription with this ID already exists.');
    }

    final subscription = Subscription(
      id: cleanId,
      title: title,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      cadence: cadence,
      nextDueAt: nextDueAt,
    );
    await subscriptions.save(subscription);
    return subscription;
  }

  Future<Subscription> update(Subscription subscription) async {
    if (await subscriptions.getById(subscription.id) == null) {
      throw StateError('Cannot update an unknown subscription.');
    }
    await subscriptions.save(subscription);
    return subscription;
  }

  Future<Subscription> archive(String id) async {
    final existing = await subscriptions.getById(id);
    if (existing == null) throw StateError('Cannot archive an unknown subscription.');
    final updated = existing.archive();
    await subscriptions.save(updated);
    return updated;
  }

  Future<Subscription> unarchive(String id) async {
    final existing = await subscriptions.getById(id);
    if (existing == null) throw StateError('Cannot unarchive an unknown subscription.');
    final updated = existing.unarchive();
    await subscriptions.save(updated);
    return updated;
  }
}
