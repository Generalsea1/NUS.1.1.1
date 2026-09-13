import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/household/application/household_invitation_repository.dart';
import 'package:nus/features/household/application/household_invitation_service.dart';
import 'package:nus/features/household/application/household_repository.dart';
import 'package:nus/features/household/application/household_service.dart';
import 'package:nus/features/household/domain/household.dart';
import 'package:nus/features/household/domain/household_invitation.dart';
import 'package:nus/features/household/presentation/household_members_page.dart';

class _FakeHouseholdRepository implements HouseholdRepository {
  List<HouseholdMember> members = [
    const HouseholdMember(householdId: 'h1', userId: 'u1', role: 'owner', status: 'active'),
    const HouseholdMember(householdId: 'h1', userId: 'u2', role: 'member', status: 'active'),
  ];

  String? updatedUserId;
  String? updatedRole;

  @override
  Future<Household> create({required String ownerUserId, required String name}) async =>
      Household(id: 'h1', ownerUserId: ownerUserId, name: name);

  @override
  Future<Household?> getById(String householdId) async =>
      const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة');

  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async => [
        HouseholdMember(
          householdId: 'h1',
          userId: userId,
          role: userId == 'u1' ? 'owner' : 'member',
          status: 'active',
        ),
      ];

  @override
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId) async => members;

  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async => member;

  @override
  Future<HouseholdMember> updateMemberRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {
    updatedUserId = userId;
    updatedRole = role;
    final updated = HouseholdMember(
      householdId: householdId,
      userId: userId,
      role: role,
      status: 'active',
    );
    members = members.map((member) => member.userId == userId ? updated : member).toList();
    return updated;
  }
}

class _FakeInvitationRepository implements HouseholdInvitationRepository {
  @override
  Future<List<HouseholdInvitation>> list({required String householdId}) async => const [];

  @override
  Future<CreatedHouseholdInvitation> create({
    required String householdId,
    required String invitedEmail,
    required String createdBy,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> revoke({required String invitationId, required String householdId}) async {}

  @override
  Future<String> accept({required String token}) async => 'h1';
}

void main() {
  testWidgets('member cannot manage roles', (tester) async {
    final repository = _FakeHouseholdRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdMembersPage(
          household: const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة'),
          currentMembership: const HouseholdMember(
            householdId: 'h1',
            userId: 'u2',
            role: 'member',
            status: 'active',
          ),
          householdService: HouseholdService(repository: repository),
          invitationService: HouseholdInvitationService(repository: _FakeInvitationRepository()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2 أعضاء نشطين'), findsOneWidget);
    expect(find.text('أنت'), findsOneWidget);
    expect(find.text('مالك'), findsOneWidget);
    expect(find.text('عضو'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('household-invite-member')), findsNothing);
    expect(find.byKey(const ValueKey<String>('household-change-role-u2')), findsNothing);
  });

  testWidgets('manager can open role actions for another non-owner member', (tester) async {
    final repository = _FakeHouseholdRepository()
      ..members = [
        const HouseholdMember(householdId: 'h1', userId: 'u1', role: 'owner', status: 'active'),
        const HouseholdMember(householdId: 'h1', userId: 'u2', role: 'member', status: 'active'),
      ];

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdMembersPage(
          household: const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة'),
          currentMembership: const HouseholdMember(
            householdId: 'h1',
            userId: 'u1',
            role: 'owner',
            status: 'active',
          ),
          householdService: HouseholdService(repository: repository),
          invitationService: HouseholdInvitationService(repository: _FakeInvitationRepository()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final changeRole = find.byKey(const ValueKey<String>('household-change-role-u2'));
    expect(changeRole, findsOneWidget);

    await tester.tap(changeRole);
    await tester.pumpAndSettle();
    expect(find.text('جعله مديرًا'), findsOneWidget);

    await tester.tap(find.text('جعله مديرًا'));
    await tester.pumpAndSettle();

    expect(repository.updatedUserId, 'u2');
    expect(repository.updatedRole, 'admin');
  });

  testWidgets('owner cannot be edited by role controls', (tester) async {
    final repository = _FakeHouseholdRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdMembersPage(
          household: const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة'),
          currentMembership: const HouseholdMember(
            householdId: 'h1',
            userId: 'u3',
            role: 'admin',
            status: 'active',
          ),
          householdService: HouseholdService(repository: repository),
          invitationService: HouseholdInvitationService(repository: _FakeInvitationRepository()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('مالك'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('household-change-role-u1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('household-change-role-u2')), findsOneWidget);
  });
}
