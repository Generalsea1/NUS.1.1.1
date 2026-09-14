import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/household/application/household_repository.dart';
import 'package:nus/features/household/application/household_service.dart';
import 'package:nus/features/household/domain/household.dart';
import 'package:nus/features/household/presentation/household_page.dart';

class _FakeRepository implements HouseholdRepository {
  @override
  Future<Household> create({required String ownerUserId, required String name}) async =>
      Household(id: 'h1', ownerUserId: ownerUserId, name: name);

  @override
  Future<Household?> getById(String householdId) async =>
      const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة');

  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async => const [
        HouseholdMember(householdId: 'h1', userId: 'u1', role: 'owner', status: 'active'),
      ];

  @override
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId) async => const [
        HouseholdMember(householdId: 'h1', userId: 'u1', role: 'owner', status: 'active'),
      ];

  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async => member;

  @override
  Future<HouseholdMember> updateMemberRole({
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

void main() {
  testWidgets('renders the current household and shared entry points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdPage(
          userId: 'u1',
          service: HouseholdService(repository: _FakeRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('بيت العيلة'), findsOneWidget);
    expect(find.text('مالك البيت'), findsOneWidget);
    expect(find.text('عضو نشط'), findsOneWidget);
    expect(find.text('مشتريات البيت المشتركة', skipOffstage: false), findsOneWidget);
    expect(find.text('أعضاء البيت', skipOffstage: false), findsOneWidget);
    expect(find.text('مهام البيت', skipOffstage: false), findsOneWidget);
    expect(find.text('NUS Copilot', skipOffstage: false), findsNothing);
  });
}