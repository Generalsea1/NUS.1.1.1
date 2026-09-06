import 'auth_state.dart';

/// Application authentication boundary.
///
/// Provider-specific login implementations enter through this contract so UI
/// and business logic never call Supabase Auth directly.
abstract interface class AuthRepository {
  AuthState get currentState;
  Stream<AuthState> get authStateChanges;

  Future<AuthState> initialize();
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<void> dispose();
}
