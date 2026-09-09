import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/household/application/household_repository.dart';
import 'package:nus/features/household/application/household_service.dart';
import 'package:nus/features/household/domain/household.dart';

class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({this.memberships = const [], this.household});

  List<HouseholdMember> memberships;
  Household? household;
  int createCount = 0;

  @override
  Future<Household> create({required String ownerUserId, required String name}) async {
    createCount++;
    household = Household(id: 'h1', ownerUserId: ownerUserId, name: name);
    return household!;
  }

  @override
  Future<Household?> getById(String householdId) async =>
      household?.id == householdId ? household : null;

  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async =>
      memberships.where((member) => member.userId == userId).toList(growable: false);

  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async {
    memberships = [...memberships, member];
    return member;
  }
}

void main() {
  test('Household round trip preserves identity and ownership', () {
    const household = Household(
      id: 'h1',
      ownerUserId: 'u1',
      name: 'My Home',
    );

    expect(Household.fromJson(household.toJson()).id, 'h1');
    expect(Household.fromJson(household.toJson()).ownerUserId, 'u1');
    expect(Household.fromJson(household.toJson()).name, 'My Home');
  });

  test('active membership is usable for current household resolution', () async {
    final repository = _FakeHouseholdRepository(
      memberships: [
        const HouseholdMember(
          householdId: 'h1',
          userId: 'u1',
          role: 'owner',
          status: 'active',
        ),
      ],
      household: const Household(id: 'h1', ownerUserId: 'u1', name: 'My Home'),
    );

    final result = await HouseholdService(repository: repository).getOrCreateForUser(userId: 'u1');

    expect(result.id, 'h1');
    expect(repository.createCount, 0);
  });

  test('creates a household only when the user has no active resolvable membership', () async {
    final repository = _FakeHouseholdRepository(
      memberships: [
        const HouseholdMember(
          householdId: 'missing',
          userId: 'u1',
          role: 'member',
          status: 'active',
        ),
      ],
    );

    final result = await HouseholdService(repository: repository).getOrCreateForUser(
      userId: 'u1',
      defaultName: 'بيت العيلة',
    );

    expect(result.name, 'بيت العيلة');
    expect(result.ownerUserId, 'u1');
    expect(repository.createCount, 1);
  });

  test('ignores inactive memberships', () async {
    final repository = _FakeHouseholdRepository(
      memberships: [
        const HouseholdMember(
          householdId: 'h1',
          userId: 'u1',
          role: 'member',
          status: 'left',
        ),
      ],
    );

    await HouseholdService(repository: repository).getOrCreateForUser(userId: 'u1');

    expect(repository.createCount, 1);
  });

  test('rejects empty user IDs before persistence', () {
    final repository = _FakeHouseholdRepository();

    expect(
      () => HouseholdService(repository: repository).getOrCreateForUser(userId: ' '),
      throwsArgumentError,
    );
  });
}
