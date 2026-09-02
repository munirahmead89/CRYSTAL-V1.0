import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../providers/database_provider.dart';
import '../../../../services/realtime/crystal_socket.dart';
import '../../data/repositories/message_repository.dart';
import '../../../../core/utils/logger.dart';

part 'message_provider.freezed.dart';

@freezed
class MessageListState with _$MessageListState {
  const factory MessageListState({
    @Default([]) List<Map<String, dynamic>> messages,
    @Default(false) bool isLoading,
    @Default(false) bool hasMore,
    String? error,
  }) = _MessageListState;
}

class MessageListNotifier extends StateNotifier<MessageListState> {
  final Ref _ref;
  final String chatId;
  RealtimeChannel? _channel;
  int _offset = 0;
  static const _pageSize = 50;

  MessageListNotifier(this._ref, this.chatId) : super(const MessageListState()) {
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true);
    // 1. Instant local cache (offline-first)
    try {
      final local = await _ref.read(messageRepositoryProvider).getLocalMessages(chatId);
      if (local.isNotEmpty) {
        state = state.copyWith(messages: local.reversed.toList(), isLoading: false);
      }
    } catch (_) {}
    // 2. Remote fetch + cache for next time
    try {
      final client = _ref.read(supabaseClientProvider);
      final messages = await client
          .from('messages')
          .select('*, reply_to:messages!reply_to_id(id, content, sender_id, message_type)')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      await _ref.read(messageRepositoryProvider).cacheRemoteMessages(chatId, messages);
      state = state.copyWith(
        messages: messages.reversed.toList(),
        isLoading: false,
        hasMore: messages.length == _pageSize,
      );
      _offset += messages.length;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    try {
      final client = _ref.read(supabaseClientProvider);
      final messages = await client
          .from('messages')
          .select('*, reply_to:messages!reply_to_id(id, content, sender_id, message_type)')
          .eq('chat_id', chatId)
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      state = state.copyWith(
        messages: [...messages.reversed.toList(), ...state.messages],
        hasMore: messages.length == _pageSize,
      );
      _offset += messages.length;
    } catch (e) {
      Logger.error('MessageProvider', 'Load more failed', e);
    }
  }

  void _subscribeToMessages() {
    final client = _ref.read(supabaseClientProvider);
    _channel = client
        .channel('messages:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) {
            final newMessage = payload.newRecord;
            if (!state.messages.any((m) => m['id'] == newMessage['id'])) {
              state = state.copyWith(
                messages: [...state.messages, newMessage],
              );
              // Persist to local store for instant reload
              try {
                _ref.read(messageRepositoryProvider).cacheRemoteMessages(chatId, [newMessage]);
              } catch (_) {}
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'message_reads',
          callback: (payload) {
            _updateReadStatus(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _updateReadStatus(Map<String, dynamic> data) {
    final messageId = data['message_id'];
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m['id'] == messageId) {
          return {...m, 'read_at': data['read_at']};
        }
        return m;
      }).toList(),
    );
  }

  Future<void> sendMessage({
    required String content,
    String? replyToId,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;

    try {
      await client.rpc('send_message', params: {
        'p_chat_id': chatId,
        'p_content': content,
        'p_message_type': messageType,
        if (replyToId != null) 'p_reply_to_id': replyToId,
        if (metadata != null) 'p_metadata': metadata,
      });
    } catch (e) {
      Logger.error('MessageProvider', 'Send failed', e);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final client = _ref.read(supabaseClientProvider);
    try {
      await client.rpc('delete_message_for_everyone', params: {
        'p_message_id': messageId,
      });
    } catch (e) {
      Logger.error('MessageProvider', 'Delete failed', e);
      rethrow;
    }
  }

  Future<void> markAsRead() async {
    final client = _ref.read(supabaseClientProvider);
    try {
      await client.rpc('mark_messages_read', params: {
        'p_chat_id': chatId,
      });
    } catch (e) {
      Logger.error('MessageProvider', 'Mark read failed', e);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final messageListProvider = StateNotifierProvider.family<MessageListNotifier, MessageListState, String>((ref, chatId) {
  return MessageListNotifier(ref, chatId);
});

class TypingNotifier extends StateNotifier<bool> {
  final Ref _ref;
  final String chatId;
  Timer? _stopTimer;

  TypingNotifier(this._ref, this.chatId) : super(false);

  void startTyping() {
    _ref.read(crystalSocketProvider.notifier).sendTyping(chatId);
    state = true;
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 3), () => stopTyping());
  }

  void stopTyping() {
    _stopTimer?.cancel();
    if (state) {
      _ref.read(crystalSocketProvider.notifier).sendStopTyping(chatId);
      state = false;
    }
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    super.dispose();
  }
}

final typingProvider = StateNotifierProvider.family<TypingNotifier, bool, String>((ref, chatId) {
  return TypingNotifier(ref, chatId);
});
