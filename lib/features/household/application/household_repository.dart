import '../domain/household.dart';

abstract interface class HouseholdRepository {
  Future<Household> create({required String ownerUserId, required String name});
  Future<Household?> getById(String householdId);
  Future<List<HouseholdMember>> listMemberships(String userId);
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId);
  Future<HouseholdMember> addMembership(HouseholdMember member);
}
