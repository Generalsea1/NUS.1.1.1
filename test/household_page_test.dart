import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/household/application/household_repository.dart';
import 'package:nus/features/household/application/household_service.dart';
import 'package:nus/features/household/domain/household.dart';
import 'package:nus/features/household/presentation/household_page.dart';

class _FakeRepository implements HouseholdRepository {
  @override
  Future<Household> create({required String ownerUserId, required String name}) async => Household(id: 'h1', ownerUserId: ownerUserId, name: name);

  @override
  Future<Household?> getById(String householdId) async => const Household(id: 'h1', ownerUserId: 'u1', name: 'بيت العيلة');

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

    final shopping = find.text('مشتريات البيت المشتركة');
    await tester.scrollUntilVisible(shopping, 350, scrollable: find.byType(Scrollable).first);
    expect(shopping, findsOneWidget);

    final members = find.text('أعضاء البيت');
    await tester.scrollUntilVisible(members, 350, scrollable: find.byType(Scrollable).first);
    expect(members, findsOneWidget);

    final tasks = find.text('مهام البيت');
    await tester.scrollUntilVisible(tasks, 350, scrollable: find.byType(Scrollable).first);
    expect(tasks, findsOneWidget);

    final copilot = find.text('NUS Copilot');
    await tester.scrollUntilVisible(copilot, 350, scrollable: find.byType(Scrollable).first);
    expect(copilot, findsOneWidget);
  });
}
