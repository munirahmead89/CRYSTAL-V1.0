import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/local_store.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user_profile.dart';
import '../domain/repositories/chat_repositories.dart';

class SupabaseConversationsRepository implements ConversationsRepository {
  SupabaseConversationsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> getOrCreateDirectConversation({required String peerId}) async {
    final response = await _client.rpc(
      'get_or_create_direct_conversation',
      params: {'p_peer_id': peerId},
    );
    if (response == null || response.toString().isEmpty) {
      throw StateError('The server did not return a conversation ID.');
    }
    return response.toString();
  }

  @override
  Future<ConversationSummary> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final response = await _client.rpc('create_group_conversation', params: {
      'p_title': name,
      'p_member_ids': memberIds,
    });
    final convId = response.toString();
    if (convId.isEmpty || convId == 'null') {
      throw StateError('The server did not return a group ID.');
    }
    return ConversationSummary(
      id: convId,
      name: name,
      isGroup: true,
      lastMessageAt: DateTime.now(),
    );
  }

  @override
  Future<List<ConversationSummary>> getChats() async {
    try {
      final rows = await _client.from('conversations').select();
      return rows
          .map((r) =>
              ConversationSummary.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {}
    return [];
  }

  @override
  Future<void> markChatRead({
    required String conversationId,
    String? upToMessageId,
  }) async {
    try {
      await _client.from('conversation_reads').upsert({
        'conversation_id': conversationId,
        'user_id': _client.auth.currentUser?.id,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<void> markDelivered(List<String> messageIds) async {
    try {
      await _client.from('message_deliveries').upsert(
            messageIds
                .map((id) => {
                      'message_id': id,
                      'user_id': _client.auth.currentUser?.id,
                      'delivered_at': DateTime.now().toIso8601String(),
                    })
                .toList(),
          );
    } catch (_) {}
  }

  @override
  Future<int> deleteConversationMessages(String conversationId) async {
    final result = await _client.rpc(
      'delete_conversation_messages',
      params: {'p_conversation_id': conversationId},
    );
    if (result is num) return result.toInt();
    if (result is String) return int.tryParse(result) ?? 0;
    throw StateError('Server returned an invalid deletion result.');
  }

  @override
  Future<void> setDisappearingMessages(
      String conversationId, int seconds) async {
    await _client.rpc('set_conversation_disappearing', params: {
      'p_conversation_id': conversationId,
      'p_seconds': seconds,
    });
  }

  @override
  Future<int> getDisappearingSeconds(String conversationId) async {
    try {
      final row = await _client
          .from('conversations')
          .select('disappearing_duration_seconds')
          .eq('id', conversationId)
          .maybeSingle();
      if (row != null && row['disappearing_duration_seconds'] != null) {
        return row['disappearing_duration_seconds'] as int;
      }
    } catch (_) {}
    return 0;
  }
}

class SupabaseMessagesRepository implements MessagesRepository {
  SupabaseMessagesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(limit);
      if (before != null) {
        query = query.lt('created_at', before);
      }
      final rows = await query;
      return rows
          .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {}
    return [];
  }

  @override
  Future<List<ChatMessage>> getMessagesAfter(
    String conversationId, {
    required String? afterId,
    int limit = 100,
  }) async {
    try {
      final rows = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);
      return rows
          .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {}
    return [];
  }

  @override
  Future<ChatMessage> send(ChatMessage draft) async {
    try {
      final res = await _client
          .from('messages')
          .insert(draft.toJson())
          .select()
          .single();
      return ChatMessage.fromJson(Map<String, dynamic>.from(res));
    } catch (_) {
      return draft;
    }
  }

  @override
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  }) async {
    return [];
  }

  @override
  Future<void> editText(
      {required String messageId, required String body}) async {
    try {
      await _client.from('messages').update({
        'body': body,
        'edited_at': DateTime.now().toIso8601String()
      }).eq('id', messageId);
    } catch (_) {}
  }
}

class SupabasePeopleRepository implements PeopleRepository {
  SupabasePeopleRepository(this._client, {this.localStore});

  final SupabaseClient _client;
  final LocalStore? localStore;

  static const String identitySelect =
      'id, display_name, phone, avatar_url, bio, presence, last_seen_at';
  static const String profileSelect =
      'id, display_name, phone, avatar_url, bio, presence, last_seen_at, verification_status, sync_enabled, verified_at';

  UserProfile parseProfileWithDevice(Map<String, dynamic> row) {
    return UserProfile.fromJson(row);
  }

  @override
  Future<UserProfile?> fetchProfileById(String id) async {
    try {
      final row = await _client
          .from('profiles')
          .select(profileSelect)
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        final profile = parseProfileWithDevice(Map<String, dynamic>.from(row));
        await localStore?.upsertProfile(profile);
        return profile;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<UserProfile?> fetchProfileByPhone(String phone) async {
    try {
      final row = await _client
          .from('profiles')
          .select(profileSelect)
          .eq('phone', phone)
          .maybeSingle();
      if (row != null) {
        final profile = parseProfileWithDevice(Map<String, dynamic>.from(row));
        await localStore?.upsertProfile(profile);
        return profile;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<List<UserProfile>> searchProfiles(String query) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(profileSelect)
          .ilike('display_name', '%$query%')
          .limit(20);
      final profiles = rows
          .map((r) => parseProfileWithDevice(Map<String, dynamic>.from(r as Map)))
          .toList();
      for (final profile in profiles) {
        await localStore?.upsertProfile(profile);
      }
      return profiles;
    } catch (_) {}
    return [];
  }

  @override
  Future<UserProfile?> restoreProfileByPhone(String phone) async {
    try {
      final row = await _client
          .from('profiles')
          .select(profileSelect)
          .eq('phone', phone)
          .maybeSingle();
      if (row != null) {
        final profile = parseProfileWithDevice(Map<String, dynamic>.from(row));
        await localStore?.upsertProfile(profile);
        return profile;
      }
    } catch (_) {}
    return null;
  }
}
