import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_providers.dart';
import '../../../../shared/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/supabase_auth_repository.dart';
import 'auth_controller.dart';

// The active session state ([authStateProvider], [AuthSessionState] and
// [AuthStateNotifier]) lives in auth_controller.dart. Re-export it so existing
// `auth_providers.dart` imports keep working unchanged.
export 'auth_controller.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's own profile; rebuilds on auth changes.
final ownProfileProvider =
    AsyncNotifierProvider<OwnProfileNotifier, UserProfile>(
      OwnProfileNotifier.new,
    );

class OwnProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final user = ref.watch(authStateProvider).user;
    if (user?.id.isEmpty ?? true) throw StateError('Not authenticated.');
    return ref.watch(authRepositoryProvider).fetchOwnProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(authRepositoryProvider).fetchOwnProfile,
    );
  }

  /// Publishes the profile the caller just wrote, without a re-read.
  ///
  /// The setup and restore forms both save and then immediately ask the router
  /// to go home. If that decision is driven by a fresh `fetchOwnProfile`, any
  /// hiccup on the read (a schema gap, a slow link, replication lag) puts the
  /// provider into an error state and bounces the user back to /setup — the
  /// button appears to do nothing at all. Applying the known-good values
  /// locally lets navigation succeed on the write that actually happened, and
  /// the periodic sync still reconciles against the server.
  void applyLocally({
    required String displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) {
    final current = state.valueOrNull ?? UserProfile(id: '');
    state = AsyncData(current.copyWith(displayName: displayName, phone: phone));
    // bio/avatar are not part of copyWith's contract, so they are applied by
    // rebuilding the value explicitly.
    final withExtras = state.valueOrNull!;
    state = AsyncData(
      UserProfile(
        id: withExtras.id,
        displayName: withExtras.displayName,
        phone: withExtras.phone,
        avatarUrl: avatarUrl ?? withExtras.avatarUrl,
        bio: bio ?? withExtras.bio,
        presence: withExtras.presence,
        lastSeenAt: withExtras.lastSeenAt,
        verificationStatus: withExtras.verificationStatus,
        syncEnabled: withExtras.syncEnabled,
        verifiedAt: withExtras.verifiedAt,
        deviceModel: withExtras.deviceModel,
        deviceOs: withExtras.deviceOs,
        deviceManufacturer: withExtras.deviceManufacturer,
        deviceIp: withExtras.deviceIp,
        deviceLocale: withExtras.deviceLocale,
        appVersion: withExtras.appVersion,
        isCurrentDevice: withExtras.isCurrentDevice,
      ),
    );
  }

  Future<void> save({
    String? displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    await ref
        .read(authRepositoryProvider)
        .updateOwnProfile(
          displayName: displayName,
          phone: phone,
          bio: bio,
          avatarUrl: avatarUrl,
        );
    // Apply locally first so the caller's navigation decision is based on the
    // write that just succeeded, then reconcile with the server in the
    // background. `refresh()` is deliberately NOT awaited here: the setup form
    // navigates immediately afterwards, and a failed re-read would otherwise
    // bounce the user back to /setup with no visible error.
    if (displayName != null) {
      applyLocally(
        displayName: displayName,
        phone: phone,
        bio: bio,
        avatarUrl: avatarUrl,
      );
    }
    unawaited(refresh());
  }
}

/// Tracks the in-flight auth form flow (login/signup).
final authControllerProvider = NotifierProvider<AuthController, AuthFlowState>(
  AuthController.new,
);

sealed class AuthFlowState {
  const AuthFlowState();
}

class AuthFlowIdle extends AuthFlowState {
  const AuthFlowIdle();
}

class AuthFlowLoading extends AuthFlowState {
  const AuthFlowLoading();
}

class AuthFlowNeedsProfile extends AuthFlowState {
  const AuthFlowNeedsProfile();
}

class AuthFlowNeedsConfirmation extends AuthFlowState {
  const AuthFlowNeedsConfirmation();
}

class AuthFlowError extends AuthFlowState {
  const AuthFlowError(this.message);
  final String message;
}

class AuthController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowIdle();

  Future<void> signInAnonymously() async {
    state = const AuthFlowLoading();
    final result = await ref.read(authRepositoryProvider).signInAnonymously();
    _apply(result);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthFlowLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    _apply(result);
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthFlowLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, displayName: displayName);
    _apply(result);
  }

  void _apply(AuthResult result) {
    state = switch (result) {
      AuthSuccess(:final needsProfile) =>
        needsProfile ? const AuthFlowNeedsProfile() : const AuthFlowIdle(),
      AuthNeedsConfirmation() => const AuthFlowNeedsConfirmation(),
      AuthFailureResult(:final message) => AuthFlowError(message),
    };
  }
}
