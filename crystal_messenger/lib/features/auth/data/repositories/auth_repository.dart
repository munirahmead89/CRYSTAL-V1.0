import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  Future<void> signInAnonymously() async {
    await _supabase.auth.signInAnonymously();
  }

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  Future<void> upsertProfile({
    required String userId,
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    await _supabase.from('profiles').upsert({
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    await _supabase.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  Future<void> claimPhone(String phone) async {
    await _supabase.rpc('claim_phone', params: {
      'p_phone': phone,
    });
  }

  Future<void> changePhoneNumber(String newPhone) async {
    await _supabase.rpc('change_phone_number', params: {
      'p_new_phone': newPhone,
    });
  }

  Future<void> deleteAccount() async {
    await _supabase.rpc('delete_account');
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});
