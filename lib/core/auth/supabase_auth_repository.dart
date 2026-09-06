import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../supabase_service.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

class SupabaseAuthRepository implements AuthRepository {
  AuthState _state = const UnauthenticatedAuthState();
  StreamSubscription<supabase.AuthState>? _subscription;
  final StreamController<AuthState> _controller = StreamController<AuthState>.broadcast();
  bool _initialized = false;
  bool _disposed = false;

  @override
  AuthState get currentState => _state;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Future<AuthState> initialize() async {
    if (_disposed) throw StateError('SupabaseAuthRepository has been disposed.');
    if (_initialized) return _state;
    _initialized = true;
    await SupabaseService.initialize();
    final client = SupabaseService.client;
    if (client == null) {
      _setState(const UnauthenticatedAuthState());
      return _state;
    }
    _setState(_mapSession(client.auth.currentSession));
    _subscription = client.auth.onAuthStateChange.listen((event) {
      if (!_disposed) _setState(_mapSession(event.session));
    });
    return _state;
  }

  @override
  Future<void> signInWithGoogle() async {
    await initialize();
    final client = SupabaseService.client;
    if (client == null) throw StateError('Supabase is not configured for this build.');
    final started = await client.auth.signInWithOAuth(
      supabase.OAuthProvider.google,
      redirectTo: 'nus://auth-callback',
      authScreenLaunchMode: supabase.LaunchMode.externalApplication,
    );
    if (!started) throw StateError('Google sign-in could not be started.');
  }

  @override
  Future<void> signOut() async {
    if (_disposed) return;
    await initialize();
    final client = SupabaseService.client;
    if (client == null) {
      _setState(const UnauthenticatedAuthState());
      return;
    }
    await client.auth.signOut();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _controller.close();
  }

  void _setState(AuthState next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  AuthState _mapSession(supabase.Session? session) {
    final user = session?.user;
    if (user == null) return const UnauthenticatedAuthState();
    final metadata = user.userMetadata;
    return AuthenticatedAuthState(
      AuthSession(
        user: AuthUser(
          id: user.id,
          email: user.email,
          displayName: _readDisplayName(metadata),
        ),
      ),
    );
  }

  String? _readDisplayName(Map<String, dynamic>? metadata) {
    if (metadata == null) return null;
    final value = metadata['display_name'] ?? metadata['full_name'] ?? metadata['name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }
}
