import '../domain/household.dart';
import 'household_repository.dart';

class HouseholdService {
  HouseholdService({required HouseholdRepository repository}) : _repository = repository;

  final HouseholdRepository _repository;

  Future<Household> getOrCreateForUser({
    required String userId,
    String defaultName = 'My Household',
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Authenticated user is required.');
    }

    final memberships = await _repository.listMemberships(cleanUserId);
    for (final membership in memberships) {
      if (!membership.isActive) continue;
      final household = await _repository.getById(membership.householdId);
      if (household != null) return household;
    }

    return _repository.create(
      ownerUserId: cleanUserId,
      name: defaultName.trim().isEmpty ? 'My Household' : defaultName.trim(),
    );
  }
}
