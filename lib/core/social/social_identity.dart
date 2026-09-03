/// Immutable social identity value model for NUS.
///
/// This layer contains no persistence, networking, authentication, or UI
/// behavior. It is intentionally independent so account/profile features can
/// depend on a stable domain contract before backend adapters are introduced.
class SocialIdentity {
  SocialIdentity({
    required String id,
    required String username,
    required String displayName,
    this.bio = '',
    this.avatarUrl,
    this.coverUrl,
    this.websiteUrl,
    this.isVerified = false,
  })  : id = _requireNonEmpty(id, 'id'),
        username = _normalizeAndValidateUsername(username),
        displayName = _validateDisplayName(displayName),
        bio = _validateBio(bio),
        avatarUrl = _validateOptionalUrl(avatarUrl, 'avatarUrl'),
        coverUrl = _validateOptionalUrl(coverUrl, 'coverUrl'),
        websiteUrl = _validateOptionalUrl(websiteUrl, 'websiteUrl');

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final String? coverUrl;
  final String? websiteUrl;
  final bool isVerified;

  static const int maxDisplayNameLength = 80;
  static const int maxBioLength = 500;
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,30}$');

  factory SocialIdentity.fromJson(Map<String, dynamic> json) {
    return SocialIdentity(
      id: _readString(json, 'id'),
      username: _readString(json, 'username'),
      displayName: _readString(json, 'displayName'),
      bio: _readNullableString(json, 'bio') ?? '',
      avatarUrl: _readNullableString(json, 'avatarUrl'),
      coverUrl: _readNullableString(json, 'coverUrl'),
      websiteUrl: _readNullableString(json, 'websiteUrl'),
      isVerified: _readBool(json, 'isVerified'),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'websiteUrl': websiteUrl,
      'isVerified': isVerified,
    };
  }

  SocialIdentity copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? websiteUrl,
    bool? isVerified,
  }) {
    return SocialIdentity(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SocialIdentity &&
            id == other.id &&
            username == other.username &&
            displayName == other.displayName &&
            bio == other.bio &&
            avatarUrl == other.avatarUrl &&
            coverUrl == other.coverUrl &&
            websiteUrl == other.websiteUrl &&
            isVerified == other.isVerified;
  }

  @override
  int get hashCode => Object.hash(
        id,
        username,
        displayName,
        bio,
        avatarUrl,
        coverUrl,
        websiteUrl,
        isVerified,
      );

  static String _requireNonEmpty(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'must not be empty');
    }
    return normalized;
  }

  static String _normalizeAndValidateUsername(String value) {
    final String normalized = value.trim().toLowerCase();
    if (!_usernamePattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'username',
        'must contain only lowercase letters, numbers, or underscores and be 3-30 characters long',
      );
    }
    return normalized;
  }

  static String _validateDisplayName(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'displayName', 'must not be empty');
    }
    if (normalized.length > maxDisplayNameLength) {
      throw ArgumentError.value(
        value,
        'displayName',
        'must be $maxDisplayNameLength characters or fewer',
      );
    }
    return normalized;
  }

  static String _validateBio(String value) {
    final String normalized = value.trim();
    if (normalized.length > maxBioLength) {
      throw ArgumentError.value(
        value,
        'bio',
        'must be $maxBioLength characters or fewer',
      );
    }
    return normalized;
  }

  static String? _validateOptionalUrl(String? value, String field) {
    if (value == null) {
      return null;
    }
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw ArgumentError.value(
        value,
        field,
        'must be a valid http or https URL',
      );
    }
    return normalized;
  }

  static String _readString(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value is! String) {
      throw FormatException('Field "$key" must be a string.');
    }
    return value;
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    String key,
  ) {
    final dynamic value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String) {
      throw FormatException('Field "$key" must be a string or null.');
    }
    return value;
  }

  static bool _readBool(Map<String, dynamic> json, String key) {
    final dynamic value = json[key];
    if (value == null) {
      return false;
    }
    if (value is! bool) {
      throw FormatException('Field "$key" must be a boolean.');
    }
    return value;
  }
}
