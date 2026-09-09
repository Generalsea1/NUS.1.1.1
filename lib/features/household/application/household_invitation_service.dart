import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../domain/household_invitation.dart';
import 'household_invitation_repository.dart';

class HouseholdInvitationService {
  HouseholdInvitationService({required HouseholdInvitationRepository repository})
      : _repository = repository;

  final HouseholdInvitationRepository _repository;
  static final Random _random = Random.secure();

  Future<List<HouseholdInvitation>> list({required String householdId}) {
    _validateId(householdId, 'householdId');
    return _repository.list(householdId: householdId.trim());
  }

  Future<CreatedHouseholdInvitation> create({
    required String householdId,
    required String invitedEmail,
    required String createdBy,
    int expiresInDays = 7,
  }) async {
    _validateId(householdId, 'householdId');
    _validateId(createdBy, 'createdBy');
    final email = invitedEmail.trim().toLowerCase();
    if (!_emailPattern.hasMatch(email)) {
      throw ArgumentError.value(invitedEmail, 'invitedEmail', 'A valid email address is required.');
    }
    if (expiresInDays < 1 || expiresInDays > 30) {
      throw ArgumentError.value(expiresInDays, 'expiresInDays', 'Invitation expiry must be between 1 and 30 days.');
    }

    final token = _newToken();
    final tokenHash = sha256.convert(utf8.encode(token)).toString();
    final expiresAt = DateTime.now().toUtc().add(Duration(days: expiresInDays));
    return _repository.create(
      householdId: householdId.trim(),
      invitedEmail: email,
      createdBy: createdBy.trim(),
      tokenHash: tokenHash,
      expiresAt: expiresAt,
    ).then((created) => CreatedHouseholdInvitation(invitation: created.invitation, token: token));
  }

  Future<void> revoke({required String invitationId, required String householdId}) {
    _validateId(invitationId, 'invitationId');
    _validateId(householdId, 'householdId');
    return _repository.revoke(
      invitationId: invitationId.trim(),
      householdId: householdId.trim(),
    );
  }

  Future<String> accept({required String token}) {
    final clean = token.trim();
    if (clean.length < 16) {
      throw ArgumentError.value(token, 'token', 'Invitation token is invalid.');
    }
    return _repository.accept(token: clean);
  }

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static void _validateId(String value, String field) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, field, '$field is required.');
    }
  }

  static String _newToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
