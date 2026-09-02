import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../providers/database_provider.dart';
import '../../../../database/app_database.dart';

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
        .order('last_message_at', ascending: false);

    // Cache to local DB
    for (final chat in response) {
      await _upsertChat(chat);
    }

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _syncChats(String userId) async {
    try {
      final response = await _supabase
          .from('chat_with_last_message')
          .select()
          .order('last_message_at', ascending: false);

      for (final chat in response) {
        await _upsertChat(chat);
      }
    } catch (e) {
      // Background sync fails silently — local cache remains
    }
  }

  Future<void> _upsertChat(Map<String, dynamic> chat) async {
    final other = chat['other_participant'];
    final otherProfile =
        other is Map ? Map<String, dynamic>.from(other) : const <String, dynamic>{};
    final lastMessage = chat['last_message'];
    final lastMessageMap =
        lastMessage is Map ? Map<String, dynamic>.from(lastMessage) : null;
    await _database.upsertChat(ChatsTableCompanion.insert(
      id: chat['chat_id'] ?? chat['id'],
      type: chat['type'] ?? 'direct',
      name: Value(
          chat['name'] ?? otherProfile['full_name'] ?? otherProfile['name']),
      avatarUrl: Value(chat['avatar_url'] ?? otherProfile['avatar_url']),
      lastMessageContent:
          Value(lastMessageMap?['content'] ?? chat['last_message_content']),
      lastMessageAt: (lastMessageMap?['created_at'] != null
              ? DateTime.tryParse(lastMessageMap!['created_at'])
              : (chat['last_message_at'] != null
                  ? DateTime.tryParse(chat['last_message_at'])
                  : null)) != null
          ? Value((lastMessageMap?['created_at'] != null
                  ? DateTime.tryParse(lastMessageMap!['created_at'])
                  : (chat['last_message_at'] != null
                      ? DateTime.tryParse(chat['last_message_at'])
                      : null))!)
          : const Value.absent(),
      unreadCount: Value(chat['unread_count'] ?? 0),
    ));
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
