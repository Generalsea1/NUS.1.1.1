class Household {
  const Household({
    required this.id,
    required this.ownerUserId,
    required this.name,
  });

  final String id;
  final String ownerUserId;
  final String name;

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        id: _requiredString(json['id'], 'id'),
        ownerUserId: _requiredString(json['ownerUserId'], 'ownerUserId'),
        name: _requiredString(json['name'], 'name'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'ownerUserId': ownerUserId,
        'name': name,
      };

  static String _requiredString(Object? value, String field) {
    final result = value?.toString().trim() ?? '';
    if (result.isEmpty) {
      throw FormatException('Household $field is required.');
    }
    return result;
  }
}

class HouseholdMember {
  const HouseholdMember({
    required this.householdId,
    required this.userId,
    required this.role,
    required this.status,
  });

  final String householdId;
  final String userId;
  final String role;
  final String status;

  bool get isActive => status == 'active';
  bool get canManage => role == 'owner' || role == 'admin';

  factory HouseholdMember.fromJson(Map<String, dynamic> json) => HouseholdMember(
        householdId: _requiredString(json['householdId'], 'householdId'),
        userId: _requiredString(json['userId'], 'userId'),
        role: _requiredString(json['role'], 'role'),
        status: _requiredString(json['status'], 'status'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'householdId': householdId,
        'userId': userId,
        'role': role,
        'status': status,
      };

  static String _requiredString(Object? value, String field) {
    final result = value?.toString().trim() ?? '';
    if (result.isEmpty) {
      throw FormatException('HouseholdMember $field is required.');
    }
    return result;
  }
}
