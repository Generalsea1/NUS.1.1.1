import '../domain/household_invitation.dart';

abstract interface class HouseholdInvitationRepository {
  Future<List<HouseholdInvitation>> list({required String householdId});
  Future<CreatedHouseholdInvitation> create({
    required String householdId,
    required String invitedEmail,
    required String createdBy,
    required String tokenHash,
    required DateTime expiresAt,
  });
  Future<void> revoke({required String invitationId, required String householdId});
  Future<String> accept({required String token});
}
