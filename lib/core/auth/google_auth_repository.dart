import 'supabase_auth_repository.dart';

/// Backward-compatible Google sign-in facade.
/// The real authentication contract lives in [SupabaseAuthRepository].
class GoogleAuthRepository {
  const GoogleAuthRepository();

  Future<void> signIn() => SupabaseAuthRepository().signInWithGoogle();
}
