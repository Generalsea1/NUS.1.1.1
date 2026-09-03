import 'profile.dart';

/// Application profile boundary.
///
/// Implementations may use different backends; application code depends on
/// this contract rather than a database client or row representation.
abstract interface class ProfileRepository {
  /// Returns the profile owned by the currently authenticated NUS identity.
  ///
  /// Returns null when there is no authenticated identity or when a profile
  /// has not been created yet.
  Future<Profile?> getCurrentProfile();
}
