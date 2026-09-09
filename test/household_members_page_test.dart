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
  @override
  Future<Household> create({required String ownerUserId, required String name}) async =>
      Household(id: 'h1', ownerUserId: ownerUserId, name: name);

  @override
  Future<Household?> getById(String householdId) async =>
      const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة');

  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async => [
        HouseholdMember(householdId: 'h1', userId: userId, role: 'member', status: 'active'),
      ];

  @override
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId) async => const [
        HouseholdMember(householdId: 'h1', userId: 'u1', role: 'owner', status: 'active'),
        HouseholdMember(householdId: 'h1', userId: 'u2', role: 'member', status: 'active'),
      ];

  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async => member;

  @override
  Future<HouseholdMember> updateMembershipRole({
    required String householdId,
    required String userId,
    required String role,
  }) async => HouseholdMember(
        householdId: householdId,
        userId: userId,
        role: role,
        status: 'active',
      );
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
  testWidgets('renders household roster without requiring admin data', (tester) async {
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
          householdService: HouseholdService(repository: _FakeHouseholdRepository()),
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
  });
}
