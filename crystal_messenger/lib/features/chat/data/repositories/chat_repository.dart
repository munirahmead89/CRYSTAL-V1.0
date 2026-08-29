import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../providers/database_provider.dart';

class ChatRepository {
  final SupabaseClient _supabase;
  final AppDatabase _database;

  ChatRepository(this._supabase, this._database);

  Future<List<Map<String, dynamic>>> getChats(String userId) async {
    // Local-first: load from Drift cache
    final localChats = await _database.getAllChats();
    if (localChats.isNotEmpty) {
      // Return local immediately, sync in background
      _syncChats(userId);
    }

    final response = await _supabase
        .from('chat_with_last_message')
        .select()
        .eq('user_id', userId)
        .order('last_message_at', ascending: false);

    // Cache to local DB
    for (final chat in response) {
      await _database.upsertChat(ChatsTableCompanion.insert(
        id: chat['chat_id'] ?? chat['id'],
        type: chat['type'] ?? 'direct',
        name: Value(chat['full_name']),
        avatarUrl: Value(chat['avatar_url']),
        lastMessageContent: Value(chat['last_message_content']),
        lastMessageAt: chat['last_message_at'] != null
            ? Value(DateTime.tryParse(chat['last_message_at']) ?? DateTime.now())
            : const Value.absent(),
        unreadCount: Value(chat['unread_count'] ?? 0),
      ));
    }

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _syncChats(String userId) async {
    try {
      final response = await _supabase
          .from('chat_with_last_message')
          .select()
          .eq('user_id', userId)
          .order('last_message_at', ascending: false);

      for (final chat in response) {
        await _database.upsertChat(ChatsTableCompanion.insert(
          id: chat['chat_id'] ?? chat['id'],
          type: chat['type'] ?? 'direct',
          name: Value(chat['full_name']),
          avatarUrl: Value(chat['avatar_url']),
          lastMessageContent: Value(chat['last_message_content']),
          lastMessageAt: chat['last_message_at'] != null
              ? Value(DateTime.tryParse(chat['last_message_at']) ?? DateTime.now())
              : const Value.absent(),
          unreadCount: Value(chat['unread_count'] ?? 0),
        ));
      }
    } catch (e) {
      // Background sync fails silently — local cache remains
    }
  }

  Future<Map<String, dynamic>> createDirectChat(String otherUserId) async {
    final result = await _supabase.rpc('create_direct_chat', params: {
      'other_user_id': otherUserId,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<void> markChatRead(String chatId) async {
    await _supabase.rpc('mark_messages_read', params: {
      'p_chat_id': chatId,
    });
  }

  Future<void> deleteChatForMe(String chatId) async {
    await _supabase.from('chat_participants').delete().eq('chat_id', chatId);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatarReference,
  }) async {
    final result = await _supabase.rpc('create_group', params: {
      'p_name': name,
      'p_member_ids': memberIds,
      if (avatarReference != null) 'p_avatar_reference': avatarReference,
    });
    return Map<String, dynamic>.from(result);
  }

  Future<String> createBroadcast(String name, List<String> recipientIds) async {
    final result = await _supabase.rpc('create_broadcast', params: {
      'p_name': name,
      'p_recipient_ids': recipientIds,
    });
    return (result is Map ? result['create_broadcast'] : result) as String;
  }

  Future<void> clearChat(String chatId) async {
    await _supabase.rpc('clear_chat', params: {
      'p_chat_id': chatId,
    });
    await _database.clearChatMessages(chatId);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final db = ref.watch(databaseProvider);
  return ChatRepository(client, db);
});
