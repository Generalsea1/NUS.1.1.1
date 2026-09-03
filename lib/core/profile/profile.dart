/// Application-level NUS profile.
///
/// The profile identity is the same stable identifier used by Supabase Auth.
/// No Supabase-specific row types or client objects cross this boundary.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: _requiredString(json, 'id'),
        displayName: _optionalString(json, 'display_name'),
        avatarUrl: _optionalString(json, 'avatar_url'),
        createdAt: _requiredDateTime(json, 'created_at'),
        updatedAt: _requiredDateTime(json, 'updated_at'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Profile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Profile(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Profile field "$key" must be a non-empty string.');
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    throw FormatException('Profile field "$key" must be a string or null.');
  }

  static DateTime _requiredDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Profile field "$key" must be an ISO-8601 string.');
  }
}
