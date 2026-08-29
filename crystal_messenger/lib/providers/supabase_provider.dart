import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = Provider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.currentSession != null
      ? AuthState(session: client.auth.currentSession, user: client.auth.currentUser)
      : const AuthState.unauthenticated();
});
