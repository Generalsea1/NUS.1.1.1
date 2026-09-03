import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/auth/auth_repository.dart';
import 'package:nus/core/auth/auth_state.dart';
import 'package:nus/core/auth/supabase_auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._state);

  AuthState _state;
  bool disposed = false;

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<AuthState> initialize() async => _state;

  @override
  Future<void> signOut() async {
    _state = const UnauthenticatedAuthState();
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test('unauthenticated state has no session or identity', () {
    const state = UnauthenticatedAuthState();

    expect(state.isAuthenticated, isFalse);
    expect(state.session, isNull);
  });

  test('authenticated state exposes only application identity', () {
    const state = AuthenticatedAuthState(
      AuthSession(
        user: AuthUser(
          id: 'user-123',
          email: 'user@example.com',
          displayName: 'NUS User',
        ),
      ),
    );

    expect(state.isAuthenticated, isTrue);
    expect(state.session!.user.id, 'user-123');
    expect(state.session!.user.email, 'user@example.com');
    expect(state.session!.user.displayName, 'NUS User');
  });

  test('application AuthState works with a provider-agnostic test double', () async {
    final repository = _FakeAuthRepository(
      const AuthenticatedAuthState(
        AuthSession(user: AuthUser(id: 'test-user')),
      ),
    );

    expect(repository.currentState.isAuthenticated, isTrue);
    await repository.signOut();
    expect(repository.currentState.isAuthenticated, isFalse);
    await repository.dispose();
    expect(repository.disposed, isTrue);
  });

  test('Supabase auth repository is safely unauthenticated without configuration',
      () async {
    final repository = SupabaseAuthRepository();

    expect(repository.currentState, isA<UnauthenticatedAuthState>());
    expect(repository.authStateChanges, isA<Stream<AuthState>>());

    final state = await repository.initialize();

    expect(state, isA<UnauthenticatedAuthState>());
    expect(repository.currentState.isAuthenticated, isFalse);
    expect(repository.currentState.session, isNull);

    await repository.dispose();
    await repository.dispose();
  });
}
