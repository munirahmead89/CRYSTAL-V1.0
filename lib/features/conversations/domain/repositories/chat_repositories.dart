import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/user_profile.dart';

/// Conversation lifecycle operations backed by Supabase.
abstract interface class ConversationsRepository {
  /// Returns the id of the existing (or newly created) direct conversation
  /// with [peerId].
  Future<String> getOrCreateDirectConversation({required String peerId});

  /// Creates a group conversation owned by the current user.
  Future<ConversationSummary> createGroup({
    required String name,
    required List<String> memberIds,
  });

  /// The current user's conversations, newest message first.
  Future<List<ConversationSummary>> getChats();

  /// Marks every message up to [upToMessageId] (or everything) as read.
  Future<void> markChatRead({
    required String conversationId,
    String? upToMessageId,
  });

  /// Marks [messageIds] as delivered for the current user.
  Future<void> markDelivered(List<String> messageIds);

  /// Permanently deletes every message in a conversation, on the server, for
  /// every participant. Returns the number of messages removed.
  ///
  /// Distinct from clearing local data: without this, a deleted chat reappeared
  /// in full on the next sync, on a reinstall, or on the other device. The
  /// *contact* is never touched - only the messages.
  ///
  /// Irreversible for both people.
  Future<int> deleteConversationMessages(String conversationId);

  /// Turns disappearing messages on or off for a conversation.
  ///
  /// [seconds] is a duration in seconds; 0 turns it off. Typical values:
  /// 86400 (24 hours), 604800 (7 days), 2592000 (30 days).
  Future<void> setDisappearingMessages(String conversationId, int seconds);

  /// The conversation's current disappearing-message timer in seconds, or 0.
  Future<int> getDisappearingSeconds(String conversationId);
}

/// Message fetch/send operations.
abstract interface class MessagesRepository {
  /// Newest-first slice of messages older than [before] (optional).
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  });

  /// Messages in [conversationId] strictly newer than the row with server id
  /// [afterId] (or all messages on first run). Used for incremental sync.
  Future<List<ChatMessage>> getMessagesAfter(
    String conversationId, {
    required String? afterId,
    int limit = 100,
  });

  /// Inserts [draft] on the server and returns the authoritative row.
  Future<ChatMessage> send(ChatMessage draft);

  /// Places (or, when [emoji] is null, removes) the current user's reaction on
  /// [messageId]. Returns the updated aggregate reaction list.
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  });

  /// Rewrites the body of a text message and records `edited_at`.
  ///
  /// Server-authorized: the sender must be the caller and the message must still
  /// be inside the editable window. Throws rather than returning false, because
  /// the caller needs to distinguish "refused" from "not attempted" to decide
  /// whether to revert an optimistic local edit.
  Future<void> editText({required String messageId, required String body});
}

/// Profile discovery for starting conversations. Phone-first, no usernames.
abstract interface class PeopleRepository {
  /// Exact user lookup by stable auth uid (used for QR payloads).
  Future<UserProfile?> fetchProfileById(String id);

  /// Exact phone lookup used by QR / "add by phone".
  Future<UserProfile?> fetchProfileByPhone(String phone);

  /// Fuzzy search across display name and phone number.
  Future<List<UserProfile>> searchProfiles(String query);

  /// Re-onboarding "welcome back" restore: the backend adopts the historical
  /// profile that owns [phone] onto the current session (display name, avatar,
  /// bio) and re-claims the phone. Returns the restored profile, or `null`
  /// when no history exists for that phone.
  Future<UserProfile?> restoreProfileByPhone(String phone);
}
