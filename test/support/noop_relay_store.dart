import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_envelope.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';

/// Neutral defaults for the relay surface of [LocalStore].
///
/// The test doubles in this suite `implement LocalStore`, so every new member
/// has to be satisfied by each of them. This mixin keeps that from turning into
/// a dozen copy-pasted no-ops per fake, and documents the "no relay here"
/// baseline: a store with no tombstones, no outstanding acknowledgements and no
/// account scope.
mixin NoopRelayStore implements LocalStore {
  @override
  String ownerId = '';

  @override
  void bindAccount(String ownerId) {
    this.ownerId = ownerId;
  }

  @override
  Future<int> adoptUnscopedRows(String ownerId) async => 0;

  @override
  Future<bool> isTombstoned(String messageId) async => false;

  @override
  Future<List<String>> tombstonedMessageIds(String conversationId) async =>
      const [];

  @override
  Future<void> writeTombstone({
    required String messageId,
    required String conversationId,
    required DeletionScope scope,
    required DateTime deletedAt,
    int payloadVersion = 1,
  }) async {}

  @override
  Future<DateTime?> deletionCursor(String conversationId) async => null;

  @override
  Future<void> recordPendingAck(
    String messageId,
    AckKind kind, {
    bool reported = false,
  }) async {}

  @override
  Future<void> markAcksReported(List<String> messageIds, AckKind kind) async {}

  @override
  Future<List<PendingAck>> pendingAcks({int limit = 200}) async => const [];

  @override
  Future<bool> owesDeliveryAck(String messageId) async => false;

  @override
  Future<void> pruneAckLedger() async {}

  @override
  Future<bool> commitIncomingMessage({
    required ChatMessage message,
    required String cursorKey,
    bool acknowledgeDelivery = true,
  }) async {
    await upsertRemoteMessage(message);
    return true;
  }

  @override
  Future<int> applyDeletionEvents(
    List<RelayDeletionEvent> events, {
    required String cursorKey,
  }) async => 0;
}
