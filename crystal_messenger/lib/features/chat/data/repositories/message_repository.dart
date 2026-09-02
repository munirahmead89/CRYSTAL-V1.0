import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../providers/database_provider.dart';
import '../../../../database/app_database.dart';
import '../../../../services/offline/offline_queue.dart';

class MessageRepository {
  final SupabaseClient _supabase;
  final AppDatabase _database;
  final OfflineQueue _offlineQueue;

  MessageRepository(this._supabase, this._database, this._offlineQueue);

  /// Optimistic send: insert locally, send to server, reconcile with server ID.
  Future<void> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? replyToId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';

    // 1. Local insert (optimistic)
    await _database.insertMessage(MessagesTableCompanion.insert(
      id: tempId,
      chatId: chatId,
      senderId: userId,
      content: Value(content),
      messageType: Value(messageType),
      replyToId: Value(replyToId),
      createdAt: DateTime.now(),
    ));

    try {
      // 2. Send via RPC
      final result = await _supabase.rpc('send_message', params: {
        'p_chat_id': chatId,
        'p_content': content,
        'p_message_type': messageType,
        if (replyToId != null) 'p_reply_to_id': replyToId,
      });
      // 3. Replace optimistic with server response
      if (result != null && result['id'] != null) {
        await _database.deleteMessage(tempId);
        await _database.insertMessage(MessagesTableCompanion.insert(
          id: result['id'],
          chatId: chatId,
          senderId: userId,
          content: Value(content),
          messageType: Value(messageType),
          replyToId: Value(replyToId),
          createdAt: DateTime.tryParse(result['created_at'] ?? '') ?? DateTime.now(),
        ));
      }
    } catch (e) {
      // Queue for retry when back online
      await _offlineQueue.enqueue('send_message', jsonEncode({
        'chat_id': chatId,
        'content': content,
        'message_type': messageType,
        if (replyToId != null) 'reply_to_id': replyToId,
      }));
    }
  }

  Future<void> deleteForEveryone(String messageId) async {
    await _supabase.rpc('delete_message_for_everyone', params: {
      'p_message_id': messageId,
    });
    await _database.deleteMessage(messageId);
  }

  Future<void> markAsRead(String chatId) async {
    await _supabase.rpc('mark_messages_read', params: {
      'p_chat_id': chatId,
    });
  }

  Future<void> markAsDelivered(String chatId, String messageId) async {
    await _supabase.rpc('mark_messages_delivered', params: {
      'p_chat_id': chatId,
      'p_message_ids': [messageId],
    });
  }

  Future<void> clearChat(String chatId) async {
    await _supabase.rpc('clear_chat', params: {
      'p_chat_id': chatId,
    });
    await _database.clearChatMessages(chatId);
  }

  /// Read cached messages from the local Drift store (instant, offline-first).
  Future<List<Map<String, dynamic>>> getLocalMessages(
    String chatId, {
    int limit = 50,
  }) async {
    final rows = await _database.getMessagesForChat(chatId, limit: limit);
    return rows.map((r) => <String, dynamic>{
      'id': r.id,
      'chat_id': r.chatId,
      'sender_id': r.senderId,
      'content': r.content,
      'message_type': r.messageType,
      'reply_to_id': r.replyToId,
      'created_at': r.createdAt.toIso8601String(),
      'is_deleted': r.isDeleted,
      'read_at': r.readAt?.toIso8601String(),
      'delivered_at': r.deliveredAt?.toIso8601String(),
    }).toList();
  }

  /// Persist remote messages into the local Drift store for instant future loads.
  Future<void> cacheRemoteMessages(
    String chatId,
    List<Map<String, dynamic>> messages,
  ) async {
    for (final m in messages) {
      final id = m['id'];
      if (id == null) continue;
      await _database.insertMessage(MessagesTableCompanion.insert(
        id: id,
        chatId: chatId,
        senderId: m['sender_id'] ?? '',
        content: Value(m['content'] ?? ''),
        messageType: Value(m['message_type'] ?? 'text'),
        replyToId: Value(m['reply_to_id']),
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        isDeleted: Value(m['is_deleted'] ?? false),
        readAt: Value(m['read_at'] != null ? DateTime.tryParse(m['read_at']) : null),
        deliveredAt: Value(m['delivered_at'] != null ? DateTime.tryParse(m['delivered_at']) : null),
      ));
    }
  }
}

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final db = ref.watch(databaseProvider);
  final queue = ref.watch(offlineQueueProvider);
  return MessageRepository(client, db, queue);
});
