import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    User? user,
    Session? session,
    @Default(false) bool isAuthenticated,
    @Default(true) bool isLoading,
    @Default(false) bool isOnboarded,
    @Default(false) bool isInitialized,
    String? error,
  }) = _AuthState;

}

class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase;

  AuthNotifier(this._supabase) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      if (session != null && user != null) {
        final profile = await _fetchProfile(user.id);
        state = AuthState(
          user: user,
          session: session,
          isAuthenticated: true,
          isOnboarded: profile?['phone'] != null,
          isInitialized: true,
        );
      } else {
        state = const AuthState.unauthenticated();
      }

      _supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session != null) {
              state = state.copyWith(
                user: session.user,
                session: session,
                isAuthenticated: true,
              );
            }
            break;
          case AuthChangeEvent.signedOut:
            state = const AuthState.unauthenticated();
            break;
          case AuthChangeEvent.tokenRefreshed:
            if (session != null) {
              state = state.copyWith(session: session, user: session.user);
            }
            break;
          default:
            break;
        }
      });
    } catch (e) {
      state = AuthState(
        isInitialized: true,
        error: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<void> signInAnonymously() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _supabase.auth.signInAnonymously();
      state = AuthState(
        user: response.user,
        session: response.session,
        isAuthenticated: true,
        isOnboarded: false,
        isInitialized: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> completeOnboarding({
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final userId = state.user?.id;
      if (userId == null) throw Exception('No user logged in');

      await _supabase.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

      state = state.copyWith(
        isOnboarded: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({String? fullName, String? bio, String? avatarUrl}) async {
    try {
      final userId = state.user?.id;
      if (userId == null) return;

      await _supabase.from('profiles').update({
        if (fullName != null) 'full_name': fullName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    state = const AuthState.unauthenticated();
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(client);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
