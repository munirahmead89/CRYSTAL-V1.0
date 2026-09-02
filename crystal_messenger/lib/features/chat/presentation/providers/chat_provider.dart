import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import '../../../../providers/database_provider.dart';

part 'chat_provider.freezed.dart';

@freezed
class ChatListState with _$ChatListState {
  const factory ChatListState({
    @Default([]) List<Map<String, dynamic>> chats,
    @Default(false) bool isLoading,
    String? error,
  }) = _ChatListState;
}

class ChatListNotifier extends StateNotifier<ChatListState> {
  final SupabaseClient _supabase;
  final Ref _ref;

  ChatListNotifier(this._supabase, this._ref) : super(const ChatListState()) {
    loadChats();
    _subscribeToChanges();
  }

  Future<void> loadChats() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabase
          .from('chat_with_last_message')
          .select()
          .order('last_message_at', ascending: false);

      state = ChatListState(
        chats: List<Map<String, dynamic>>.from(response),
        isLoading: false,
      );
    } catch (e) {
      state = ChatListState(isLoading: false, error: e.toString());
    }
  }

  void _subscribeToChanges() {
    _supabase
        .channel('chat-list-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => loadChats(),
        )
        .subscribe();
  }

  Future<Map<String, dynamic>> createDirectChat(String otherUserId) async {
    final result = await _supabase.rpc('create_direct_chat', params: {
      'other_user_id': otherUserId,
    });
    await loadChats();
    return Map<String, dynamic>.from(result);
  }

  Future<void> refresh() => loadChats();
}

final chatListProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChatListNotifier(client, ref);
});

// Active chat state (which chat is currently open)
class ActiveChatState {
  final String? chatId;
  final Set<String> typingUserIds;
  const ActiveChatState({this.chatId, this.typingUserIds = const {}});
}

class ActiveChatNotifier extends StateNotifier<ActiveChatState> {
  ActiveChatNotifier() : super(const ActiveChatState());

  void setActiveChat(String? chatId) {
    state = ActiveChatState(chatId: chatId);
  }

  void addTypingUser(String userId) {
    state = ActiveChatState(
      chatId: state.chatId,
      typingUserIds: {...state.typingUserIds, userId},
    );
  }

  void removeTypingUser(String userId) {
    state = ActiveChatState(
      chatId: state.chatId,
      typingUserIds: {...state.typingUserIds}..remove(userId),
    );
  }
}

final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ActiveChatState>((ref) {
  return ActiveChatNotifier();
});
