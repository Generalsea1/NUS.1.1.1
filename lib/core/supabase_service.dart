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
/// This foundation does not perform authentication or data access. When
/// runtime configuration is absent, NUS remains fully local-first.
class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

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
    } catch (_) {
      debugPrint(
        'Supabase foundation: initialization failed; '
        'continuing in local-first mode.',
      );
    }
  }
}
