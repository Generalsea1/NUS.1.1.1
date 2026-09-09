class HouseholdInvitation {
  const HouseholdInvitation({
    required this.id,
    required this.householdId,
    required this.invitedEmail,
    required this.status,
    required this.expiresAt,
    required this.createdBy,
    this.acceptedAt,
  });

  final String id;
  final String householdId;
  final String invitedEmail;
  final String status;
  final DateTime expiresAt;
  final String createdBy;
  final DateTime? acceptedAt;

  bool get isPending => status == 'pending';
  bool get isExpired => status == 'expired' || expiresAt.isBefore(DateTime.now().toUtc());

  factory HouseholdInvitation.fromJson(Map<String, dynamic> json) => HouseholdInvitation(
        id: _required(json['id'], 'id'),
        householdId: _required(json['householdId'], 'householdId'),
        invitedEmail: _required(json['invitedEmail'], 'invitedEmail').toLowerCase(),
        status: _required(json['status'], 'status'),
        expiresAt: DateTime.parse(_required(json['expiresAt'], 'expiresAt')).toUtc(),
        createdBy: _required(json['createdBy'], 'createdBy'),
        acceptedAt: json['acceptedAt'] == null
            ? null
            : DateTime.parse(_required(json['acceptedAt'], 'acceptedAt')).toUtc(),
      );

  static String _required(Object? value, String field) {
    final clean = value?.toString().trim() ?? '';
    if (clean.isEmpty) throw FormatException('Household invitation $field is required.');
    return clean;
  }
}

class CreatedHouseholdInvitation {
  const CreatedHouseholdInvitation({
    required this.invitation,
    required this.token,
  });

  final HouseholdInvitation invitation;
  /// One-time raw token. It is returned to the caller and never persisted.
  final String token;
}
