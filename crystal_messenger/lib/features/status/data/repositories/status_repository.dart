import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

class StatusRepository {
  final SupabaseClient _supabase;

  StatusRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getStatusFeed() async {
    final response = await _supabase.rpc('get_status_feed');
    return List<Map<String, dynamic>>.from(response ?? []);
  }

  Future<List<Map<String, dynamic>>> getActiveStatuses() async {
    final response = await _supabase
        .from('statuses')
        .select('*, user:profiles!user_id(full_name, avatar_url)')
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createTextStatus({
    required String content,
    String backgroundColor = '#005C4B',
    String textColor = '#FFFFFF',
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('statuses').insert({
      'user_id': userId,
      'content': content,
      'media_type': 'text',
      'background_color': backgroundColor,
      'text_color': textColor,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  Future<void> createMediaStatus({
    required String mediaUrl,
    required String mediaType,
    String? caption,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('statuses').insert({
      'user_id': userId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
  }

  Future<void> recordView(String statusId) async {
    await _supabase.rpc('record_status_view', params: {
      'p_status_id': statusId,
    });
  }
}

final statusRepositoryProvider = Provider<StatusRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StatusRepository(client);
});
