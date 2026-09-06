import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Runtime/build-time Supabase configuration for NUS.
///
/// Values are supplied with `--dart-define` (or an equivalent build-system
/// mechanism). No Supabase credential is stored in source control.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool isValid({required String url, required String publishableKey}) {
    final uri = Uri.tryParse(url);
    return publishableKey.isNotEmpty &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
  }

  static bool get isConfigured =>
      isValid(url: url, publishableKey: publishableKey);

  static String get status => isConfigured ? 'configured' : 'not configured';
}

/// Owns the single application-level Supabase initialization boundary.
///
/// This foundation initializes Supabase once. For the production mobile app,
/// an unauthenticated first launch immediately starts the NUS Google sign-in
/// flow so the application does not silently operate as an anonymous user.
class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;
  static bool _startupGoogleFlowStarted = false;

  static bool get isInitialized => _initialized;

  /// Returns the singleton Supabase client only after successful init.
  static SupabaseClient? get client {
    if (!_initialized) return null;
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'Supabase foundation: configuration unavailable; '
        'continuing in local-first mode.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      _initialized = true;
      debugPrint('Supabase foundation: initialized successfully.');

      await _requestStartupGoogleSignInIfNeeded();
    } catch (error) {
      debugPrint(
        'Supabase foundation: initialization failed; '
        'continuing in local-first mode. $error',
      );
    }
  }

  /// Starts Google authentication on the first unauthenticated mobile launch.
  ///
  /// Existing Supabase sessions are preserved and do not trigger another
  /// browser flow. `signInWithOAuth` returns after the browser flow starts;
  /// the persisted Supabase session is then restored when Google redirects
  /// back through `nus://auth-callback`.
  static Future<void> _requestStartupGoogleSignInIfNeeded() async {
    if (_startupGoogleFlowStarted || kIsWeb) return;

    final platform = defaultTargetPlatform;
    final isMobile = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS;
    if (!isMobile) return;

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;

    _startupGoogleFlowStarted = true;

    try {
      final started = await auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'nus://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      debugPrint(
        started
            ? 'NUS startup auth: Google sign-in flow started.'
            : 'NUS startup auth: Google sign-in flow was not started.',
      );
    } on AuthException catch (error) {
      debugPrint('NUS startup auth: Google sign-in failed: ${error.message}');
    } catch (error) {
      debugPrint('NUS startup auth: unexpected Google sign-in error: $error');
    }
  }
}
