import '../domain/household.dart';
import 'household_repository.dart';

class HouseholdService {
  HouseholdService({required HouseholdRepository repository}) : _repository = repository;

  final HouseholdRepository _repository;

  Future<List<HouseholdMember>> currentMemberships(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Authenticated user is required.');
    }
    final memberships = await _repository.listMemberships(cleanUserId);
    return List<HouseholdMember>.unmodifiable(memberships);
  }

  Future<List<HouseholdMember>> householdMembers(String householdId) async {
    final cleanHouseholdId = householdId.trim();
    if (cleanHouseholdId.isEmpty) {
      throw ArgumentError.value(householdId, 'householdId', 'Household is required.');
    }
    final members = await _repository.listHouseholdMembers(cleanHouseholdId);
    return List<HouseholdMember>.unmodifiable(members);
  }

  Future<HouseholdMember> updateMemberRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {
    final cleanHouseholdId = householdId.trim();
    final cleanUserId = userId.trim();
    final cleanRole = role.trim().toLowerCase();
    if (cleanHouseholdId.isEmpty) {
      throw ArgumentError.value(householdId, 'householdId', 'Household is required.');
    }
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Member is required.');
    }
    if (cleanRole != 'admin' && cleanRole != 'member') {
      throw ArgumentError.value(role, 'role', 'Member role must be admin or member.');
    }
    return _repository.updateMembershipRole(
      householdId: cleanHouseholdId,
      userId: cleanUserId,
      role: cleanRole,
    );
  }

  Future<Household> getOrCreateForUser({
    required String userId,
    String defaultName = 'My Household',
  }) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Authenticated user is required.');
    }

    final memberships = await currentMemberships(cleanUserId);
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
