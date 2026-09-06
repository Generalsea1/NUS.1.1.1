import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

/// Email/password authentication for the NUS account itself.
///
/// Gemini authorization remains a separate Google OAuth consent flow.
class EmailAuthRepository {
  const EmailAuthRepository();

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const EmailAuthConfigurationException();
    }

    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final client = SupabaseService.client;
    if (client == null) {
      throw const EmailAuthConfigurationException();
    }

    return client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }
}

class EmailAuthConfigurationException implements Exception {
  const EmailAuthConfigurationException();

  @override
  String toString() =>
      'Supabase authentication is not configured for this NUS build.';
}
