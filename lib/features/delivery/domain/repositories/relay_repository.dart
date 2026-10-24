import '../message_lifecycle.dart';
import '../relay_envelope.dart';

/// The trusted server operations the message relay depends on.
///
/// Everything here is a server-side `SECURITY DEFINER` function, not a direct
/// table write. That is deliberate: `delivered_at`, `read_at`, `deleted_at`
/// and `retention_state` are server-owned, and the only way a client can
/// influence them is by proving, server-side, that it did the corresponding
/// work first.
///
/// Implementations must be safe to call with no network: failures are
/// reported, never thrown past the caller's state machine, so the outbox and
/// ack ledger can retain their rows and retry.
abstract interface class RelayRepository {
  /// Durably stores a message, idempotently.
  ///
  /// Returns [SendOutcome.recovered] when the server already holds a row for
  /// [RelaySendRequest.clientMessageId], which is the expected outcome when a
  /// response was lost. Callers must treat both outcomes as success.
  Future<RelaySendResult> sendMessage(RelaySendRequest request);

  /// Records that this device durably holds each of [messageIds].
  ///
  /// Must only be called after the local transaction that stored the messages
  /// has committed. Replaying after a lost response is safe and idempotent.
  Future<RelayAckResult> acknowledgeDelivered({
    required List<String> messageIds,
    required String deviceId,
  });

  /// Records that the user has read a conversation up to [upToMessageId].
  ///
  /// [upToMessageId] bounds the claim: without it the server cannot tell which
  /// messages were actually on screen and would mark the whole conversation
  /// read. Read receipts are suppressed entirely when the sender's privacy
  /// setting disallows them.
  Future<RelayReadResult> markRead({
    required String conversationId,
    required String deviceId,
    String? upToMessageId,
  });

  /// Incremental message fetch from [afterMessageId] (exclusive), ascending.
  Future<RelayPage> fetchMessagesAfter({
    required String conversationId,
    String? afterMessageId,
    int limit,
  });

  /// Historical page strictly before [beforeIso], ascending.
  Future<RelayPage> fetchMessagesBefore({
    required String conversationId,
    String? beforeIso,
    int limit,
  });

  /// Deletion events strictly newer than [sinceIso].
  ///
  /// This is the only recovery path for deletions: an id-ordered message pull
  /// structurally cannot observe a removal, so a device that was offline when
  /// someone deleted a message would otherwise keep showing it forever.
  Future<List<RelayDeletionEvent>> fetchDeletionEvents({
    DateTime? sinceIso,
    int limit,
  });

  /// Deletes a message for every participant. Server-authorized, tombstoned,
  /// and idempotent.
  Future<bool> deleteMessage({required String messageId, DeletionScope scope});
}
