import '../../../../shared/models/user_profile.dart';
import '../entities/app_user.dart';

sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess({this.needsProfile = false});
  final bool needsProfile;
}

class AuthNeedsConfirmation extends AuthResult {
  const AuthNeedsConfirmation();
}

class AuthFailureResult extends AuthResult {
  const AuthFailureResult(this.message);
  final String message;
}

/// Thrown when an anonymous-only (unverified) account tries cloud device
/// registration / cross-device sync. Single-device chat still works.
class DeviceSyncRequiresVerifiedException implements Exception {
  const DeviceSyncRequiresVerifiedException()
    : message =
          'Device sync needs a verified email account. Add your email in '
          'Settings to sync across devices.';

  final String message;

  @override
  String toString() => message;
}

/// Contract for authentication and own-profile operations.
abstract interface class AuthRepository {
  Stream<AppUser?> authStateChanges();

  AppUser? get currentUser;

  Future<AuthResult> signIn({required String email, required String password});

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthResult> signInAnonymously();

  Future<void> signOut();

  /// Upgrades an anonymous (guest) session into a permanent email/password
  /// account. The same [AppUser.id] is kept, so chats, messages and the
  /// profile row survive the transition. Returns a user-facing error string on
  /// failure, or `null` on success.
  Future<String?> linkGuestAccount({
    required String email,
    required String password,
  });

  /// Attempts to refresh the current session (used to lift the "degraded"
  /// offline suppression once connectivity returns). True when a live session
  /// is still available.
  Future<bool> refreshSessionIfAlive();

  /// True when a session was persisted for this install (from an earlier
  /// sign-in). Used at cold start to hold the router in a "restoring" state
  /// until gotrue finishes recovering the session, so a previously signed-in
  /// user is NEVER bounced to onboarding just because the async restore had
  /// not emitted yet.
  Future<bool> hasPersistedSession();

  Future<UserProfile> fetchOwnProfile();

  Future<void> updateOwnProfile({
    String? displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  });

  Future<void> registerDevice({
    required String deviceId,
    required String platform,
    required String deviceName,
    String? pushToken,
    String? deviceModel,
    String? deviceOs,
    String? deviceManufacturer,
    String? deviceIp,
    String? deviceLocale,
    String? appVersion,
  });

  Future<void> updatePresence(String status);

  /// Permanently deletes the user's account and all associated data.
  /// Returns an error string on failure, or `null` on success.
  Future<String?> deleteAccount();
}
