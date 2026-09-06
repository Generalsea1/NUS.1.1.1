import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_service.dart';

class GoogleAuthRepository {
  const GoogleAuthRepository();

  Future<bool> signIn() async {
    await SupabaseService.initialize();
    final client = SupabaseService.client;
    if (client == null) {
      throw const GoogleAuthConfigurationException();
    }

    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'nus://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('provider is not enabled')) {
        throw const GoogleProviderDisabledException();
      }
      if (message.contains('redirect') || message.contains('redirect_uri')) {
        throw const GoogleRedirectConfigurationException();
      }
      rethrow;
    }
  }
}

class GoogleAuthConfigurationException implements Exception {
  const GoogleAuthConfigurationException();

  String message(bool isArabic) => isArabic
      ? 'اتصال Supabase غير متاح في نسخة NUS الحالية. لازم بناء النسخة بإعدادات Supabase الصحيحة.'
      : 'Supabase is not available in this NUS build. Rebuild with the correct Supabase runtime configuration.';

  @override
  String toString() => message(true);
}

class GoogleProviderDisabledException implements Exception {
  const GoogleProviderDisabledException();

  String message(bool isArabic) => isArabic
      ? 'تسجيل الدخول بـGoogle غير مفعّل على خادم NUS حاليًا. لازم تفعيل Google من Supabase Auth ثم إعادة المحاولة.'
      : 'Google sign-in is not enabled on the NUS Supabase project. Enable Google in Supabase Auth, then try again.';

  @override
  String toString() => message(true);
}

class GoogleRedirectConfigurationException implements Exception {
  const GoogleRedirectConfigurationException();

  String message(bool isArabic) => isArabic
      ? 'رابط رجوع Google إلى NUS غير مضبوط. لازم إضافة nus://auth-callback إلى Redirect URLs في Supabase Auth.'
      : 'Google return URL is not configured. Add nus://auth-callback to the Supabase Auth Redirect URLs.';

  @override
  String toString() => message(true);
}
