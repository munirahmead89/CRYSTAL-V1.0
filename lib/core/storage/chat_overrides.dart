import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences.dart';

/// Client-side management overrides for chats (delete-for-me semantics).
///
/// All three are per-device: the conversation stays on the server, but its
/// list row is hidden (deleted / blocked) or its badge is suppressed (muted)
/// until the user reverses the action.
class ChatOverrides {
  const ChatOverrides({
    this.muted = const {},
    this.blocked = const {},
    this.deleted = const {},
  });

  /// Conversation ids whose unread badge (and any notification) is suppressed.
  final Set<String> muted;

  /// Peer ids whose conversations are hidden from the list until unblocked.
  final Set<String> blocked;

  /// Conversation ids hidden from the list until a new message arrives or the
  /// user opens the chat again (WhatsApp-style "delete chat").
  final Set<String> deleted;

  bool isMuted(String conversationId) => muted.contains(conversationId);
  bool isBlocked(String peerId) => blocked.contains(peerId);
  bool isDeleted(String conversationId) => deleted.contains(conversationId);

  ChatOverrides copyWith({
    Set<String>? muted,
    Set<String>? blocked,
    Set<String>? deleted,
  }) {
    return ChatOverrides(
      muted: muted ?? this.muted,
      blocked: blocked ?? this.blocked,
      deleted: deleted ?? this.deleted,
    );
  }
}

/// Hydrated from [AppPreferences] on first read and kept in sync afterwards.
final chatOverridesProvider =
    StateNotifierProvider<ChatOverridesNotifier, ChatOverrides>(
      ChatOverridesNotifier.new,
    );

class ChatOverridesNotifier extends StateNotifier<ChatOverrides> {
  ChatOverridesNotifier(this._ref) : super(const ChatOverrides()) {
    _hydrate();
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    final prefs = await _ref.read(appPreferencesProvider.future);
    state = ChatOverrides(
      muted: prefs.mutedChats.toSet(),
      blocked: prefs.blockedPeers.toSet(),
      deleted: prefs.deletedChats.toSet(),
    );
  }

  Future<void> _persist() async {
    final prefs = await _ref.read(appPreferencesProvider.future);
    await prefs.setMutedChats(state.muted.toList());
    await prefs.setBlockedPeers(state.blocked.toList());
    await prefs.setDeletedChats(state.deleted.toList());
  }

  /// Toggle notification muting for a conversation.
  Future<void> toggleMute(String conversationId) async {
    final muted = {...state.muted};
    if (!muted.remove(conversationId)) muted.add(conversationId);
    state = state.copyWith(muted: muted);
    await _persist();
  }

  /// Hide every conversation involving [peerId] until unblocked.
  Future<void> blockPeer(String peerId) async {
    state = state.copyWith(blocked: {...state.blocked, peerId});
    await _persist();
  }

  Future<void> unblockPeer(String peerId) async {
    final blocked = {...state.blocked}..remove(peerId);
    state = state.copyWith(blocked: blocked);
    await _persist();
  }

  /// Hide a conversation (delete-for-me) and purge its cached messages.
  Future<void> deleteConversation(String conversationId) async {
    state = state.copyWith(deleted: {...state.deleted, conversationId});
    await _persist();
  }

  /// Reveal a previously deleted conversation (used when a blocked chat is
  /// reopened via a contact preview).
  Future<void> restoreConversation(String conversationId) async {
    final deleted = {...state.deleted}..remove(conversationId);
    state = state.copyWith(deleted: deleted);
    await _persist();
  }
}
