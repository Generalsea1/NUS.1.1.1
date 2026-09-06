import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

class GoogleAuthRepository {
  const GoogleAuthRepository();

  Future<bool> signIn() async {
    final client = SupabaseService.client;
    if (client == null) return false;
    return client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'nus://auth-callback',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }
}
