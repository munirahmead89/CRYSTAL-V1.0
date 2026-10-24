import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/core/sync/outbox_sync.dart';
import 'package:crystal_messenger/features/auth/presentation/providers/auth_providers.dart';
import 'package:crystal_messenger/features/conversations/presentation/providers/chat_providers.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:crystal_messenger/shared/utils/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Forwards a received attachment into another conversation.
///
/// ## Why this is its own path
///
/// Sending normally goes through `ChatController`, a Riverpod `FamilyNotifier`
/// scoped to one conversation that owns that thread's UI. The controller you are
/// looking at belongs to the *source* chat, so it cannot post into a different
/// one.
///
/// This writes straight to the local store and the outbox, which are
/// conversation-agnostic by design: a queued row carries its own
/// `conversation_id`, so the ordinary flush delivers it to whichever conversation
/// it names. The destination thread picks it up through its own realtime
/// subscription, exactly as if it had been sent from there.
///
/// ## No re-upload
///
/// The attachment is forwarded with its original `uploadId` and manifest
/// intact, so the bytes are not sent a second time. Supabase Storage already
/// holds them under that id and both devices resolve the same object. Re-uploading
/// a 200 MB video to forward it would be the obvious thing to get wrong here.
///
/// ## Same delivery guarantee as an ordinary send
///
/// The row lands in the outbox like any other message, so it survives the app
/// being killed mid-forward and flushes on reconnect.
class ForwardMediaService {
  ForwardMediaService({
    required this.store,
    required this.outbox,
    required this.getMyId,
  });

  final LocalStore store;
  final OutboxSyncEngine outbox;
  final String? Function() getMyId;

  /// Queues [attachment] into [targetConversationId], carrying [caption] if the
  /// original message had text. Returns the new message's client id.
  ///
  /// [sourceConversationId] is used only to refuse a forward back into the
  /// same thread, which would be a no-op the user did not mean.
  Future<String> forward({
    required String targetConversationId,
    required String sourceConversationId,
    Attachment? attachment,
    String? body,
    String? caption,
  }) async {
    if (targetConversationId == sourceConversationId) {
      throw ArgumentError('Cannot forward a message into its own conversation');
    }
    // A forward needs something to forward. The picker used to return
    // immediately when `attachment == null`, which silently made forwarding a
    // text-only message impossible - the long-press menu had no Forward entry
    // for text at all.
    final text = (body ?? caption ?? '').trim();
    if (attachment == null && text.isEmpty) {
      throw ArgumentError('Nothing to forward');
    }
    final me = getMyId();
    if (me == null || me.isEmpty) throw StateError('Not signed in');

    // Deliberately NOT a reply: `reply_to_message_id` must point at a row in
    // the same conversation, and forwarding across conversations would dangle.
    final clientMessageId = generateUuid();
    final message = ChatMessage(
      id: clientMessageId,
      clientMessageId: clientMessageId,
      conversationId: targetConversationId,
      senderId: me,
      // Type is derived from the mime type rather than assumed from the
      // conversation, because a photo forwarded into a group is still a photo.
      type: attachment != null ? _typeFor(attachment) : 'text',
      body: text.isEmpty ? null : text,
      attachment: attachment,
      createdAt: DateTime.now(),
      outgoing: true,
      // The recipient sees this too, which is the point: a forwarded photo
      // presented as original is how misinformation spreads.
      forwarded: true,
      localState: MessageLocalState.queued,
    );

    await store.upsertLocalMessage(message);
    await store.enqueueOutbox(message);
    // Try immediately; offline it simply stays queued until reconnect.
    await outbox.flush();
    return clientMessageId;
  }

  /// Forwards the same message into several conversations.
  ///
  /// Each target gets its own outbox row with its own client message id, so
  /// one failing destination cannot roll back the others. That matters because
  /// the common case is forwarding to several people at once, and a partial
  /// success is the expected outcome on a flaky connection - not an exception
  /// worth surfacing.
  ///
  /// Returns the ids of the conversations that were queued. Failures are
  /// collected into [ForwardResult.failures] rather than thrown.
  Future<ForwardResult> forwardToMany({
    required List<String> targetConversationIds,
    required String sourceConversationId,
    Attachment? attachment,
    String? body,
  }) async {
    final queued = <String>[];
    final failures = <String, Object>{};
    for (final targetId in targetConversationIds) {
      try {
        await forward(
          targetConversationId: targetId,
          sourceConversationId: sourceConversationId,
          attachment: attachment,
          body: body,
        );
        queued.add(targetId);
      } catch (error) {
        failures[targetId] = error;
      }
    }
    return ForwardResult(queued: queued, failures: failures);
  }

  static String _typeFor(Attachment a) {
    final mime = a.mimeType ?? '';
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('audio/')) return 'voice';
    return 'file';
  }
}

/// Outcome of a multi-target forward.
class ForwardResult {
  const ForwardResult({required this.queued, required this.failures});

  /// Conversation ids the message was queued into.
  final List<String> queued;

  /// Conversation id -> the error that stopped it. A target that was already
  /// the source thread lands here.
  final Map<String, Object> failures;

  bool get allSucceeded => failures.isEmpty;
}

final forwardMediaServiceProvider = Provider<ForwardMediaService>((ref) {
  return ForwardMediaService(
    store: ref.watch(localStoreProvider),
    outbox: ref.watch(syncEngineProvider),
    getMyId: () => ref.read(authStateProvider).user?.id,
  );
});
