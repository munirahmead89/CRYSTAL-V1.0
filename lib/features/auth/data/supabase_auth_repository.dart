import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/security/supabase_secure_storage.dart';
import '../../../../features/conversations/data/supabase_chat_repositories.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../../shared/utils/phone_normalizer.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

/// Supabase-backed [AuthRepository] implementation.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Hard ceiling on any interactive auth request.
  ///
  /// gotrue performs these calls with `http` and no timeout of its own, so on a
  /// stalled-but-not-closed connection the future never completes. The UI
  /// switches to a busy state *before* awaiting, which means an unbounded
  /// request here leaves the button permanently disabled with no way to recover
  /// — the "Get started does nothing" symptom. Bounding it turns a hang into a
  /// readable error the user can retry.
  static const Duration _authTimeout = Duration(seconds: 20);

  static AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
    );
  }

  @override
  AppUser? get currentUser {
    final supaUser = _client.auth.currentUser;
    // A local synthetic ID is not a Supabase identity and must never make the
    // configured app appear authenticated. Offline cache access is handled by
    // the sync layer; server operations require a real persisted session.
    return _mapUser(supaUser);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map(
      (state) => _mapUser(state.session?.user ?? _client.auth.currentUser),
    );
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(_authTimeout);
      if (response.user == null) {
        return const AuthFailureResult('Invalid email or password.');
      }
      return const AuthSuccess();
    } on AuthException catch (e) {
      return AuthFailureResult(_friendlyMessage(e.message));
    } on TimeoutException {
      return const AuthFailureResult(
        'The request timed out. Check your connection and try again.',
      );
    } catch (e) {
      return AuthFailureResult(
        _isNetworkError(e)
            ? 'You appear to be offline. Connect to the internet and try again.'
            : 'Could not sign in. Try again.',
      );
    }
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    try {
      final response = await _client.auth
          .signInAnonymously()
          .timeout(_authTimeout);
      if (response.user != null) {
        return const AuthSuccess();
      }
      return const AuthFailureResult(
        'Anonymous identity could not be created. Please try again.',
      );
    } catch (e) {
      return AuthFailureResult(
        _isNetworkError(e)
            ? 'You appear to be offline. Connect to the internet and try again.'
            : 'Could not create an anonymous identity. Try again.',
      );
    }

  }

  @override
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth
          .signUp(
            email: email,
            password: password,
            data: {
              'display_name': displayName,
            },
          )
          .timeout(_authTimeout);
      if (response.session?.user != null || response.user != null) {
        return const AuthSuccess();
      }
      return const AuthFailureResult('Could not create the account.');
    } on AuthException catch (e) {
      return AuthFailureResult(_friendlyMessage(e.message));
    } on TimeoutException {
      return const AuthFailureResult(
        'The request timed out. Check your connection and try again.',
      );
    } catch (e) {
      return AuthFailureResult(
        _isNetworkError(e)
            ? 'You appear to be offline. Connect to the internet and try again.'
            : 'Could not create the account.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<bool> hasPersistedSession() async {
    try {
      return await const SecureSupabaseLocalStorage().hasAccessToken();
    } catch (_) {
      // Keystore reads can fail on device restore; treat as signed out so the
      // user reaches onboarding instead of an infinite restoring screen.
      return false;
    }
  }

  @override
  Future<bool> refreshSessionIfAlive() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return false;
      final response = await _client.auth.refreshSession(session.refreshToken);
      return response.session != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<UserProfile> fetchOwnProfile() async {
    final id = currentUser?.id;
    if (id == null) throw StateError('Not authenticated.');
    final peopleRepo = SupabasePeopleRepository(_client);

    try {
      final row = await _client
          .from('profiles')
          .select(SupabasePeopleRepository.profileSelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return UserProfile(id: id);
      return peopleRepo.parseProfileWithDevice(Map<String, dynamic>.from(row));
    } catch (error) {
      // The device embed is decoration, not identity. If the backend is missing
      // those columns the whole query fails, `ownProfileProvider` errors, and
      // the router bounces the user back to /setup — making the setup form's
      // save button look completely inert. Retry with the identity columns
      // alone so a schema gap can never trap the user in onboarding.
      if (!_isMissingColumnError(error)) rethrow;
      final row = await _client
          .from('profiles')
          .select(SupabasePeopleRepository.identitySelect)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return UserProfile(id: id);
      return peopleRepo.parseProfileWithDevice(Map<String, dynamic>.from(row));
    }
  }

  /// Postgres error code 42703 (undefined_column) / 42P01, i.e. the query is
  /// structurally fine but references something the database does not have.
  static bool _isMissingColumnError(Object error) {
    final text = '$error'.toLowerCase();
    return text.contains('does not exist') ||
        text.contains('undefined_column') ||
        text.contains('42703') ||
        text.contains('pgrst200');
  }

  @override
  Future<void> updateOwnProfile({
    String? displayName,
    String? phone,
    String? bio,
    String? avatarUrl,
  }) async {
    var id = currentUser?.id;
    if (id == null || id.isEmpty) {
      await signInAnonymously();
      id = currentUser?.id;
    }
    if (id == null || id.isEmpty) {
      throw StateError('A Supabase session is required to save a profile.');
    }

    await _client.from('profiles').upsert({
      'id': id,
      if (displayName != null) 'display_name': displayName,
      if (phone != null) 'phone': normalizePhoneForStorage(phone),
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'is_anonymous': _client.auth.currentUser?.appMetadata['provider'] == 'anonymous',
      'sync_enabled': true,
      'verification_status': _client.auth.currentUser?.appMetadata['provider'] == 'anonymous'
          ? 'unverified'
          : 'verified',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'id');
  }

  @override
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
  }) async {
    try {
      await _client.rpc(
        'register_device',
        params: {
          'p_device_id': deviceId,
          'p_platform': platform,
          'p_device_name': deviceName,
          'p_push_token': pushToken,
          'p_device_model': deviceModel,
          'p_device_os': deviceOs,
          'p_device_manufacturer': deviceManufacturer,
          'p_device_ip': deviceIp,
          'p_device_locale': deviceLocale,
          'p_app_version': appVersion,
        },
      );
    } on PostgrestException catch (e) {
      if (e.message.toLowerCase().contains('verified')) {
        // Cloud device registration is an email feature.
        throw const DeviceSyncRequiresVerifiedException();
      }
      rethrow;
    }
  }

  @override
  Future<void> updatePresence(String status) async {
    try {
      await _client.rpc('set_presence', params: {'p_status': status});
    } catch (_) {
      // Presence is best-effort.
    }
  }

  /// Maps raw auth errors to copy that makes sense in a product UI, instead of
  /// leaking the raw JSON/gotrue/Postgres message.
  ///
  /// Some GoTrue releases surface the whole error envelope (including
  /// `{"code":...}` and raw Postgres constraints) as `AuthException.message`.
  /// If it is JSON, only the `message` field is kept before mapping; anything
  /// unrecognized falls back to a friendly generic line — never raw bytes.
  static String _friendlyMessage(String raw) {
    final message = _tryExtractMessage(raw).toLowerCase();
    if (message.isEmpty) return 'Something went wrong. Please try again.';
    if (message.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (message.contains('not confirmed') || message.contains('unverified')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'That email is already registered. Try signing in instead.';
    }
    if (message.contains('database error creating')) {
      return 'Could not create an account. Please try again.';
    }
    if (message.contains('unexpected_failure') ||
        message.contains('database error') ||
        message.contains('null value in column') ||
        message.contains('violates not-null constraint')) {
      return 'Something went wrong on our side. Please try again.';
    }
    if (message.contains('too many requests') ||
        message.contains('rate limit')) {
      return 'Too many attempts. Wait a moment and try again.';
    }
    if (message.contains('password should be at least') ||
        message.contains('at least 6')) {
      return 'Password must be at least 6 characters long.';
    }
    if (message.contains('signup') && message.contains('disabled')) {
      return 'New accounts are temporarily disabled.';
    }
    if (message.contains('captcha') || message.contains('security')) {
      return 'Security check failed. Try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// If `raw` is a JSON error envelope like
  /// `{"code":"unexpected_failure","message":"..."}` it returns the `message`
  /// field; otherwise the original string.
  static String _tryExtractMessage(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return raw;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Not JSON — fall through.
    }
    return raw;
  }

  /// Test hook: maps raw GoTrue/Postgres errors to user-facing copy.
  @visibleForTesting
  static String friendlyMessage(String raw) => _friendlyMessage(raw);

  /// Cross-platform network-error detection. Avoids importing `dart:io`
  /// (which would break Web builds) by probing the runtime type.
  static bool _isNetworkError(Object error) {
    final text = '${error.runtimeType} $error'.toLowerCase();
    if (text.contains('socket') || text.contains('timeout')) return true;
    if (text.contains('clientexception')) return true;
    if (text.contains('httpexception')) return true;
    if (text.contains('failed to fetch')) return true;
    if (text.contains('network is unreachable')) return true;
    if (text.contains('connection reset')) return true;
    if (text.contains('no route to host')) return true;
    return false;
  }

  @override
  Future<String?> linkGuestAccount({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      if (response.user != null) {
        return null;
      }
      return 'Could not link account.';
    } on AuthException catch (e) {
      return _friendlyMessage(e.message);
    } catch (e) {
      return _isNetworkError(e)
          ? 'You are offline. Connect to the internet and try again.'
          : 'Could not link account. Please try again.';
    }
  }

  @override
  Future<String?> deleteAccount() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return 'Not signed in.';

      // Delete all user data from profiles, conversations, messages, etc.
      // This is done via a Supabase RPC function that handles cascading deletes
      await _client.rpc('delete_user_account', params: {'p_user_id': userId});

      // The RPC performs privileged deletion server-side. The Flutter client
      // must never call auth.admin or carry a service-role key.
      await _client.auth.signOut();

      return null;
    } on AuthException catch (e) {
      return _friendlyMessage(e.message);
    } catch (e) {
      return _isNetworkError(e)
          ? 'You are offline. Connect to the internet and try again.'
          : 'Could not delete account. Please try again.';
    }
  }
}
