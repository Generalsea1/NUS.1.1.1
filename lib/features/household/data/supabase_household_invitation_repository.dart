import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/household_invitation_repository.dart';
import '../domain/household_invitation.dart';

class SupabaseHouseholdInvitationRepository implements HouseholdInvitationRepository {
  const SupabaseHouseholdInvitationRepository();

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) {
      throw const HouseholdInvitationConfigurationException();
    }
    return client;
  }

  @override
  Future<List<HouseholdInvitation>> list({required String householdId}) async {
    final id = householdId.trim();
    if (id.isEmpty) throw ArgumentError.value(householdId, 'householdId');
    final rows = await _client()
        .from('household_invitations')
        .select('id,household_id,invited_email,status,expires_at,created_by,accepted_at')
        .eq('household_id', id)
        .order('created_at', ascending: false);
    return rows
        .map((row) => HouseholdInvitation.fromJson(<String, dynamic>{
              'id': row['id'],
              'householdId': row['household_id'],
              'invitedEmail': row['invited_email'],
              'status': row['status'],
              'expiresAt': row['expires_at'],
              'createdBy': row['created_by'],
              'acceptedAt': row['accepted_at'],
            }))
        .toList(growable: false);
  }

  @override
  Future<CreatedHouseholdInvitation> create({
    required String householdId,
    required String invitedEmail,
    required String createdBy,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    final row = await _client()
        .from('household_invitations')
        .insert(<String, dynamic>{
          'household_id': householdId.trim(),
          'invited_email': invitedEmail.trim().toLowerCase(),
          'token_hash': tokenHash.trim().toLowerCase(),
          'role': 'member',
          'status': 'pending',
          'expires_at': expiresAt.toUtc().toIso8601String(),
          'created_by': createdBy.trim(),
        })
        .select('id,household_id,invited_email,status,expires_at,created_by,accepted_at')
        .single();

    final invitation = HouseholdInvitation.fromJson(<String, dynamic>{
      'id': row['id'],
      'householdId': row['household_id'],
      'invitedEmail': row['invited_email'],
      'status': row['status'],
      'expiresAt': row['expires_at'],
      'createdBy': row['created_by'],
      'acceptedAt': row['accepted_at'],
    });
    // The application service wraps this result with the raw one-time token.
    // This repository receives only its hash, so the raw secret can never be
    // reconstructed from persisted data.
    return CreatedHouseholdInvitation(invitation: invitation, token: '');
  }

  @override
  Future<void> revoke({required String invitationId, required String householdId}) async {
    await _client()
        .from('household_invitations')
        .update(<String, dynamic>{
          'status': 'revoked',
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          'revoked_by': SupabaseService.client?.auth.currentUser?.id,
        })
        .eq('id', invitationId.trim())
        .eq('household_id', householdId.trim());
  }

  @override
  Future<String> accept({required String token}) async {
    final result = await _client().rpc(
      'accept_household_invitation',
      params: <String, dynamic>{'invite_token': token.trim()},
    );
    if (result == null) {
      throw StateError('Invitation was accepted but no household was returned.');
    }
    return result.toString();
  }
}

class HouseholdInvitationConfigurationException implements Exception {
  const HouseholdInvitationConfigurationException();

  @override
  String toString() => 'Supabase household invitation storage is not configured for this build.';
}
