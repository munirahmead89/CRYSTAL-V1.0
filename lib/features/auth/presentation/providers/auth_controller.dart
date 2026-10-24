import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/connectivity/connectivity_providers.dart';
import '../../domain/entities/app_user.dart';
import 'auth_providers.dart';

/// Snapshot of the authentication session the UI and the router can render
/// against. Unlike the old stream value it is synchronous (no `.isLoading`
/// states), so redirects can never bounce an already-signed-in user to
/// onboarding because a stream briefly emitted `null`.
class AuthSessionState {
  const AuthSessionState({
    this.user,
    this.restored = false,
    this.degraded = false,
    this.restoring = false,
  });

  /// The signed-in user, or `null` when signed out.
  final AppUser? user;

  /// True when the session was recovered from encrypted local storage at boot
  /// (i.e. the app opened offline with a previously persisted session).
  final bool restored;

  /// True while a sign-out was suppressed because the network flaked
  /// mid-session (token-refresh failure evicted the Supabase session). The
  /// user stays in the app shell; the flag is lifted once connectivity returns
  /// and the session is proven live (or the degraded shell is dropped).
  final bool degraded;

  /// True between cold start and the moment a persisted session is either
  /// recovered (→ signed in) or proven absent (→ onboarding). While restoring,
  /// the router must NOT redirect to onboarding — a killed-and-reopened app
  /// with a saved session never flashes the welcome screen even though gotrue
  /// recovers the session asynchronously.
  final bool restoring;

  bool get isSignedIn => user != null && user!.id.isNotEmpty;

  AuthSessionState copyWith({
    bool clearUser = false,
    AppUser? user,
    bool? restored,
    bool? degraded,
    bool? restoring,
  }) {
    return AuthSessionState(
      user: clearUser ? null : (user ?? this.user),
      restored: restored ?? this.restored,
      degraded: degraded ?? this.degraded,
      restoring: restoring ?? this.restoring,
    );
  }

  @override
  String toString() =>
      'AuthSessionState(user: $user, restored: $restored, degraded: $degraded, '
      'restoring: $restoring)';
}

/// Single source of truth for the current auth session.
///
/// Principles:
/// * A local persisted session grants app entry immediately, regardless of
///   connectivity (cold-start recovery done by Supabase is reflected here).
/// * Only the router/user is redirected to onboarding when the user is truly
///   signed out — never because a connectivity check reported `false`.
/// * An explicit [signOut] always ends the session, even offline.
/// * gotrue emits `signedOut` both for explicit sign-out AND for auto-refresh
///   failure while offline. Those are indistinguishable by event alone, so
///   [AuthStateNotifier] gates them with the connectivity stream.
final authStateProvider = NotifierProvider<AuthStateNotifier, AuthSessionState>(
  AuthStateNotifier.new,
);

class AuthStateNotifier extends Notifier<AuthSessionState> {
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<bool>? _onlineSub;
  Timer? _restoreTimer;
  bool _userInitiatedSignOut = false;
  bool _disposed = false;

  @override
  AuthSessionState build() {
    final repository = ref.watch(authRepositoryProvider);

    // Synchronous restore: whatever Supabase recovered from its (encrypted)
    // local storage is available before the first frame.
    final current = repository.currentUser;
    state = AuthSessionState(user: current, restored: current != null);

    _authSub = repository.authStateChanges().listen(_onAuthChange);
    ref.onDispose(() {
      _disposed = true;
      _authSub?.cancel();
      _restoreTimer?.cancel();
    });

    // Lift the degraded flag as soon as the network returns.
    _onlineSub = ref
        .read(connectivityServiceProvider)
        .onConnectionChanged()
        .listen((event) {
          if (event) _handleConnectivityRestored();
        });
    ref.onDispose(() => _onlineSub?.cancel());

    // No synchronous session yet — a persisted one may still be restoring
    // asynchronously. Hold "restoring" so the router keeps its place and the
    // user is never bounced to onboarding on a cold start.
    if (current == null) {
      state = state.copyWith(restoring: true);
      _recoverPersistedSession();
    }

    return state;
  }

  /// Settles the cold-start "restoring" state: either there is no persisted
  /// session (→ onboarding, which is the only legitimate time it shows) or
  /// there is one (→ wait for gotrue's own restore event to deliver the user,
  /// with a bounded watchdog so a failed storage read cannot hang forever).
  Future<void> _recoverPersistedSession() async {
    var hasLocal = false;
    try {
      hasLocal = await ref.read(authRepositoryProvider).hasPersistedSession();
    } catch (_) {
      hasLocal = false;
    }
    if (_disposed) return;
    if (!hasLocal) {
      state = const AuthSessionState();
      return;
    }
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(seconds: 8), () {
      if (_disposed) return;
      if (state.restoring) {
        // The storage read said a session exists but gotrue never delivered
        // it (corrupt keystore). End the wait so the user reaches onboarding.
        state = const AuthSessionState();
      }
    });
  }

  void _onAuthChange(AppUser? user) {
    if (user != null) {
      _userInitiatedSignOut = false;
      _restoreTimer?.cancel();
      _restoreTimer = null;
      state = state.copyWith(
        user: user,
        restored: true,
        restoring: false,
        degraded: false,
      );
      return;
    }

    // While a persisted session is still restoring at cold start, gotrue emits
    // a null INITIAL_SESSION event before the recovered session. Ignore it —
    // it is not a sign-out. _recoverPersistedSession / the watchdog settle the
    // state when the outcome is known.
    if (state.restoring) return;

    if (_userInitiatedSignOut) {
      _userInitiatedSignOut = false;
      state = state.copyWith(clearUser: true, restored: false);
      return;
    }

    // A $null event with an active session: either a genuine server-side
    // sign-out or an offline token-refresh failure that evicted the local
    // session. Do not bounce the user to onboarding because of a network
    // blip — suppress the sign-out until we are online again.
    final online = ref.read(isOnlineProvider).valueOrNull ?? true;
    if (!online) {
      state = state.copyWith(degraded: true);
      return;
    }

    state = state.copyWith(clearUser: true, restored: false);
  }

  Future<void> _handleConnectivityRestored() async {
    if (!state.degraded || !state.isSignedIn) return;
    final alive = await ref
        .read(authRepositoryProvider)
        .refreshSessionIfAlive();
    if (alive) {
      state = state.copyWith(degraded: false);
    } else if (state.degraded) {
      // The session is genuinely gone (refresh tokens expired mid-outage).
      // End the degraded shell so the router can return to onboarding with a
      // clear state — this is not a connectivity toggle, it is a dead session.
      state = state.copyWith(clearUser: true, restored: false, degraded: false);
    }
  }

  /// Explicit sign-out. Always lands the user on onboarding, even offline.
  Future<void> signOut() async {
    _userInitiatedSignOut = true;
    _restoreTimer?.cancel();
    _restoreTimer = null;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Network failure during sign-out: gotrue has still cleared the local
      // session at this point; fall through and end the state regardless.
    }
    state = state.copyWith(
      clearUser: true,
      restored: false,
      degraded: false,
      restoring: false,
    );
  }

  /// Upgrades a guest account to a permanent email/password account. Returns a
  /// user-facing error string, or `null` on success. The `USER_UPDATED` auth
  /// event (and this notifier's user state) refresh automatically.
  Future<String?> linkGuestAccount({
    required String email,
    required String password,
  }) {
    return ref
        .read(authRepositoryProvider)
        .linkGuestAccount(email: email, password: password);
  }
}
