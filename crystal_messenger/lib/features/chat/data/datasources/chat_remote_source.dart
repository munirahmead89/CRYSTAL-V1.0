import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRemoteSource {
  final SupabaseClient _supabase;

  ChatRemoteSource(this._supabase);

  Future<List<Map<String, dynamic>>> getChats(String userId) async {
    final response = await _supabase
        .from('chat_with_last_message')
        .select()
        .eq('user_id', userId)
        .order('last_message_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> createDirectChat(String otherUserId) async {
    final result = await _supabase.rpc('create_direct_chat', params: {
      'other_user_id': otherUserId,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<void> markMessagesRead(String chatId) async {
    await _supabase.rpc('mark_messages_read', params: {
      'p_chat_id': chatId,
    });
  }

  Future<void> deleteChatForMe(String chatId) async {
    await _supabase.from('chat_participants').delete().eq('chat_id', chatId);
  }

  Future<void> clearChat(String chatId) async {
    await _supabase.rpc('clear_chat', params: {
      'p_chat_id': chatId,
    });
  }
}
