import '../auth/auth_repository.dart';
import '../auth/auth_state.dart';
import '../supabase_service.dart';
import 'profile.dart';
import 'profile_repository.dart';

/// Supabase-backed profile infrastructure.
///
/// The authenticated identity is obtained only through [AuthRepository].
/// The repository never accepts a caller-provided profile id for the current
/// profile lookup, preventing the application boundary from choosing another
/// user's identity.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository({
    required AuthRepository authRepository,
    Future<Map<String, dynamic>?> Function(String userId)? fetchRow,
  })  : _authRepository = authRepository,
        _fetchRow = fetchRow;

  final AuthRepository _authRepository;
  final Future<Map<String, dynamic>?> Function(String userId)? _fetchRow;

  @override
  Future<Profile?> getCurrentProfile() async {
    final authState = _authRepository.currentState;
    if (!authState.isAuthenticated) return null;

    final session = authState.session;
    final userId = session?.user.id;
    if (userId == null || userId.isEmpty) return null;

    final row = _fetchRow != null
        ? await _fetchRow(userId)
        : await _fetchFromSupabase(userId);
    if (row == null) return null;

    return SupabaseProfileMapper.fromRow(row);
  }

  Future<Map<String, dynamic>?> _fetchFromSupabase(String userId) async {
    final client = SupabaseService.client;
    if (client == null) return null;

    return client
        .from('profiles')
        .select('id, display_name, avatar_url, created_at, updated_at')
        .eq('id', userId)
        .maybeSingle();
  }
}

/// Infrastructure-only mapping from a Supabase row to the application model.
class SupabaseProfileMapper {
  const SupabaseProfileMapper._();

  static Profile fromRow(Map<String, dynamic> row) => Profile(
        id: _requiredString(row, 'id'),
        displayName: _optionalString(row, 'display_name'),
        avatarUrl: _optionalString(row, 'avatar_url'),
        createdAt: _requiredDateTime(row, 'created_at'),
        updatedAt: _requiredDateTime(row, 'updated_at'),
      );

  static String _requiredString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Supabase profile field "$key" is invalid.');
  }

  static String? _optionalString(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    throw FormatException('Supabase profile field "$key" is invalid.');
  }

  static DateTime _requiredDateTime(
    Map<String, dynamic> row,
    String key,
  ) {
    final value = row[key];
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    throw FormatException('Supabase profile field "$key" is invalid.');
  }
}
