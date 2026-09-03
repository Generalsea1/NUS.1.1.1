/// Application-level representation of the authenticated user's identity.
///
/// This type deliberately contains no Supabase-specific objects, tokens, or
/// provider metadata. Authentication infrastructure maps provider state into
/// this stable application contract.
class AuthUser {
  const AuthUser({
    required this.id,
    this.email,
    this.displayName,
  });

  final String id;
  final String? email;
  final String? displayName;
}

/// Minimal application session representation.
///
/// Supabase remains responsible for the underlying session and token
/// persistence. NUS only consumes the authenticated identity it needs.
class AuthSession {
  const AuthSession({required this.user});

  final AuthUser user;
}

/// Authentication state exposed to the application layer.
///
/// The domain layer never imports or exposes Supabase Auth types.
sealed class AuthState {
  const AuthState();

  bool get isAuthenticated;
  AuthSession? get session;
}

class UnauthenticatedAuthState extends AuthState {
  const UnauthenticatedAuthState();

  @override
  bool get isAuthenticated => false;

  @override
  AuthSession? get session => null;
}

class AuthenticatedAuthState extends AuthState {
  const AuthenticatedAuthState(this.session);

  @override
  final AuthSession session;

  @override
  bool get isAuthenticated => true;
}
