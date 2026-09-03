import 'auth_state.dart';

/// Application authentication boundary.
///
/// Provider-specific login implementations are intentionally added in later
/// phases. This interface keeps UI and business logic independent of Supabase.
abstract interface class AuthRepository {
  AuthState get currentState;
  Stream<AuthState> get authStateChanges;

  Future<AuthState> initialize();
  Future<void> signOut();
  Future<void> dispose();
}
