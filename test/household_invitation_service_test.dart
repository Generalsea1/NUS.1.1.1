import 'package:flutter_test/flutter_test.dart';

import 'package:nus/features/household/application/household_invitation_repository.dart';
import 'package:nus/features/household/application/household_invitation_service.dart';
import 'package:nus/features/household/domain/household_invitation.dart';

class _FakeInvitationRepository implements HouseholdInvitationRepository {
  final List<HouseholdInvitation> items = [];
  String? lastTokenHash;
  String? acceptedToken;

  @override
  Future<List<HouseholdInvitation>> list({required String householdId}) async =>
      items.where((item) => item.householdId == householdId).toList();

  @override
  Future<CreatedHouseholdInvitation> create({
    required String householdId,
    required String invitedEmail,
    required String createdBy,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    lastTokenHash = tokenHash;
    final invitation = HouseholdInvitation(
      id: 'invite-1',
      householdId: householdId,
      invitedEmail: invitedEmail,
      status: 'pending',
      expiresAt: expiresAt,
      createdBy: createdBy,
    );
    items.add(invitation);
    return CreatedHouseholdInvitation(invitation: invitation, token: '');
  }

  @override
  Future<void> revoke({required String invitationId, required String householdId}) async {}

  @override
  Future<String> accept({required String token}) async {
    acceptedToken = token;
    return 'household-1';
  }
}

void main() {
  test('creates a normalized invitation with a one-time token and hash', () async {
    final repository = _FakeInvitationRepository();
    final service = HouseholdInvitationService(repository: repository);

    final created = await service.create(
      householdId: ' h1 ',
      invitedEmail: ' Family@Example.COM ',
      createdBy: ' user-1 ',
      expiresInDays: 7,
    );

    expect(created.token, isNotEmpty);
    expect(created.token.length, greaterThanOrEqualTo(16));
    expect(created.invitation.householdId, 'h1');
    expect(created.invitation.invitedEmail, 'family@example.com');
    expect(repository.lastTokenHash, isNotNull);
    expect(repository.lastTokenHash, isNot(created.token));
    expect(created.invitation.expiresAt.isAfter(DateTime.now().toUtc()), isTrue);
  });

  test('rejects invalid email and expiry inputs before persistence', () async {
    final repository = _FakeInvitationRepository();
    final service = HouseholdInvitationService(repository: repository);

    expect(
      () => service.create(
        householdId: 'h1',
        invitedEmail: 'not-an-email',
        createdBy: 'u1',
      ),
      throwsArgumentError,
    );
    expect(
      () => service.create(
        householdId: 'h1',
        invitedEmail: 'a@example.com',
        createdBy: 'u1',
        expiresInDays: 31,
      ),
      throwsArgumentError,
    );
    expect(repository.items, isEmpty);
  });

  test('accept forwards only a validated token to the repository boundary', () async {
    final repository = _FakeInvitationRepository();
    final service = HouseholdInvitationService(repository: repository);

    final householdId = await service.accept(token: '0123456789abcdef');

    expect(householdId, 'household-1');
    expect(repository.acceptedToken, '0123456789abcdef');
    expect(
      () => service.accept(token: 'short'),
      throwsArgumentError,
    );
  });
}
