import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';

class CallRepository {
  final SupabaseClient _supabase;

  CallRepository(this._supabase);

  Future<List<Map<String, dynamic>>> getCallHistory(String userId) async {
    final response = await _supabase
        .from('calls')
        .select('*, caller:profiles!caller_id(full_name, avatar_url)')
        .eq('caller_id', userId)
        .order('started_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> logCall({
    required String chatId,
    required String callerId,
    required String callType,
    required String status,
    int? duration,
  }) async {
    final result = await _supabase.rpc('log_call', params: {
      'p_chat_id': chatId,
      'p_caller_id': callerId,
      'p_call_type': callType,
      'p_status': status,
      if (duration != null) 'p_duration': duration,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<void> updateCallStatus({
    required String callId,
    required String status,
    int? duration,
  }) async {
    await _supabase.from('calls').update({
      'status': status,
      if (duration != null) 'duration': duration,
      if (status == 'ended' || status == 'missed' || status == 'declined')
        'ended_at': DateTime.now().toIso8601String(),
    }).eq('id', callId);
  }
}

final callRepositoryProvider = Provider<CallRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return CallRepository(client);
});
