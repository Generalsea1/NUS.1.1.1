import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

class GoogleAuthRepository {
  const GoogleAuthRepository();

  Future<bool> signIn() async {
    final client = SupabaseService.client;
    if (client == null) return false;

    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'nus://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('provider is not enabled')) {
        throw const GoogleProviderDisabledException();
      }
      rethrow;
    }
  }
}

class GoogleProviderDisabledException implements Exception {
  const GoogleProviderDisabledException();

  String message(bool isArabic) => isArabic
      ? 'تسجيل الدخول بـGoogle غير مفعّل على خادم NUS حاليًا. لازم تفعيل Google من Supabase Auth ثم إعادة المحاولة.'
      : 'Google sign-in is not enabled on the NUS Supabase project. Enable Google in Supabase Auth, then try again.';

  @override
  String toString() => message(true);
}
