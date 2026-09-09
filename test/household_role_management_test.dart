import 'package:flutter_test/flutter_test.dart';
import 'package:nus/features/household/application/household_repository.dart';
import 'package:nus/features/household/application/household_service.dart';
import 'package:nus/features/household/domain/household.dart';

class _Repository implements HouseholdRepository {
  final members = <HouseholdMember>[
    const HouseholdMember(householdId: 'h1', userId: 'u2', role: 'member', status: 'active'),
  ];

  @override
  Future<Household> create({required String ownerUserId, required String name}) async =>
      Household(id: 'h1', ownerUserId: ownerUserId, name: name);
  @override
  Future<Household?> getById(String householdId) async =>
      const Household(id: 'h1', ownerUserId: 'u1', name: 'Home');
  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async => members;
  @override
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId) async => members;
  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async => member;
  @override
  Future<HouseholdMember> updateMembershipRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {
    return HouseholdMember(
      householdId: householdId,
      userId: userId,
      role: role,
      status: 'active',
    );
  }
}

void main() {
  test('allows only admin/member target roles at service boundary', () async {
    final service = HouseholdService(repository: _Repository());
    final result = await service.updateMemberRole(householdId: 'h1', userId: 'u2', role: 'admin');
    expect(result.role, 'admin');

    expect(
      () => service.updateMemberRole(householdId: 'h1', userId: 'u2', role: 'owner'),
      throwsArgumentError,
    );
  });
}
