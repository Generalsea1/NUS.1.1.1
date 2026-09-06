import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/auth/auth_repository.dart';
import 'package:nus/core/auth/auth_state.dart';
import 'package:nus/core/profile/profile.dart';
import 'package:nus/core/profile/profile_repository.dart';
import 'package:nus/core/profile/supabase_profile_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._state);

  AuthState _state;

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<AuthState> initialize() async => _state;

  @override
  Future<void> signInWithGoogle() async {
    _state = const AuthenticatedAuthState(
      AuthSession(user: AuthUser(id: 'google-test-user')),
    );
  }

  @override
  Future<void> signOut() async {
    _state = const UnauthenticatedAuthState();
  }

  @override
  Future<void> dispose() async {}
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  final Profile? profile;

  @override
  Future<Profile?> getCurrentProfile() async => profile;
}

Profile _testProfile() {
  return Profile(
    id: '11111111-1111-1111-1111-111111111111',
    displayName: 'NUS User',
    avatarUrl: 'https://example.com/avatar.png',
    createdAt: DateTime.parse('2026-09-03T10:00:00Z'),
    updatedAt: DateTime.parse('2026-09-03T11:00:00Z'),
  );
}

void main() {
  test('Profile model creates and parses without database row types', () {
    final original = _testProfile();
    final parsed = Profile.fromJson(original.toJson());

    expect(parsed.id, original.id);
    expect(parsed.displayName, original.displayName);
    expect(parsed.avatarUrl, original.avatarUrl);
    expect(parsed.createdAt, original.createdAt);
    expect(parsed.updatedAt, original.updatedAt);
  });

  test('authenticated identity is the profile ownership key', () async {
    const userId = '11111111-1111-1111-1111-111111111111';
    final authRepository = _FakeAuthRepository(
      const AuthenticatedAuthState(
        AuthSession(user: AuthUser(id: userId)),
      ),
    );
    String? requestedId;

    final repository = SupabaseProfileRepository(
      authRepository: authRepository,
      fetchRow: (id) async {
        requestedId = id;
        return {
          'id': id,
          'display_name': 'NUS User',
          'avatar_url': null,
          'created_at': '2026-09-03T10:00:00Z',
          'updated_at': '2026-09-03T11:00:00Z',
        };
      },
    );

    final profile = await repository.getCurrentProfile();

    expect(requestedId, userId);
    expect(profile, isNotNull);
    expect(profile!.id, userId);
  });

  test('unauthenticated current-profile request is safe and makes no fetch', () async {
    final authRepository = _FakeAuthRepository(
      const UnauthenticatedAuthState(),
    );
    var fetchCalled = false;

    final repository = SupabaseProfileRepository(
      authRepository: authRepository,
      fetchRow: (_) async {
        fetchCalled = true;
        return null;
      },
    );

    final profile = await repository.getCurrentProfile();

    expect(profile, isNull);
    expect(fetchCalled, isFalse);
  });

  test('ProfileRepository boundary works with a fake implementation', () async {
    final expected = _testProfile();
    final repository = _FakeProfileRepository(expected);

    final profile = await repository.getCurrentProfile();

    expect(profile, same(expected));
    expect(profile, isA<Profile>());
  });

  test('Supabase row mapping returns Profile, not a Supabase row representation', () {
    final value = SupabaseProfileMapper.fromRow({
      'id': '11111111-1111-1111-1111-111111111111',
      'display_name': 'NUS User',
      'avatar_url': null,
      'created_at': '2026-09-03T10:00:00Z',
      'updated_at': '2026-09-03T11:00:00Z',
    });

    expect(value, isA<Profile>());
    expect(value.id, '11111111-1111-1111-1111-111111111111');
    expect(value.toJson(), isA<Map<String, dynamic>>());
  });
}
