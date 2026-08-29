import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../providers/supabase_provider.dart';
import 'chat_provider.dart';

part 'chat_settings_provider.freezed.dart';

@freezed
class ChatSettingsState with _$ChatSettingsState {
  const factory ChatSettingsState({
    @Default(false) bool isPinned,
    @Default(false) bool isArchived,
    @Default(false) bool isMuted,
    DateTime? muteUntil,
    int? disappearingTimer,
    @Default(false) bool isLoading,
  }) = _ChatSettingsState;
}

class ChatSettingsNotifier extends StateNotifier<ChatSettingsState> {
  final Ref _ref;
  final String chatId;

  ChatSettingsNotifier(this._ref, this.chatId)
      : super(const ChatSettingsState()) {
    load();
  }

  Future<void> load() async {
    final client = _ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser!.id;
    try {
      final rows = await client
          .from('chat_participants')
          .select('is_pinned, is_archived, is_muted, mute_until')
          .eq('chat_id', chatId)
          .eq('user_id', userId)
          .limit(1);
      if (rows.isNotEmpty) {
        final r = rows.first;
        state = state.copyWith(
          isPinned: r['is_pinned'] ?? false,
          isArchived: r['is_archived'] ?? false,
          isMuted: r['is_muted'] ?? false,
          muteUntil: r['mute_until'] != null
              ? DateTime.tryParse(r['mute_until'])
              : null,
        );
      }
      final chat = await client
          .from('chats')
          .select('disappearing_timer')
          .eq('id', chatId)
          .limit(1);
      if (chat.isNotEmpty) {
        state = state.copyWith(disappearingTimer: chat.first['disappearing_timer']);
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> togglePin() async {
    final next = !state.isPinned;
    state = state.copyWith(isPinned: next);
    await _ref.read(supabaseClientProvider).rpc('set_chat_pin',
        params: {'p_chat_id': chatId, 'p_pinned': next});
    _ref.invalidate(chatListProvider);
  }

  Future<void> toggleArchive() async {
    final next = !state.isArchived;
    state = state.copyWith(isArchived: next);
    await _ref.read(supabaseClientProvider).rpc('set_chat_archive',
        params: {'p_chat_id': chatId, 'p_archived': next});
    _ref.invalidate(chatListProvider);
  }

  Future<void> setMute(bool muted, {Duration? duration}) async {
    state = state.copyWith(
        isMuted: muted,
        muteUntil: duration != null ? DateTime.now().add(duration) : null);
    await _ref.read(supabaseClientProvider).rpc('set_chat_mute', params: {
      'p_chat_id': chatId,
      'p_muted': muted,
      'p_mute_until': duration != null
          ? DateTime.now().add(duration).toIso8601String()
          : null,
    });
    _ref.invalidate(chatListProvider);
  }

  Future<void> setDisappearingTimer(int? seconds) async {
    state = state.copyWith(disappearingTimer: seconds);
    await _ref.read(supabaseClientProvider).rpc('set_disappearing_timer',
        params: {'p_chat_id': chatId, 'p_timer': seconds});
  }
}

final chatSettingsProvider =
    StateNotifierProvider.family<ChatSettingsNotifier, ChatSettingsState, String>(
        (ref, chatId) => ChatSettingsNotifier(ref, chatId));
