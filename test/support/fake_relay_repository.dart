import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_failure.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_envelope.dart';
import 'package:crystal_messenger/features/delivery/domain/repositories/relay_repository.dart';

/// In-memory [RelayRepository] with scripted failures.
///
/// Written to be driven from a test, not to be a faithful Supabase emulator:
/// its job is to let the relay's own invariants be asserted — idempotent send,
/// device-scoped acknowledgements, tombstoned fetches — without a network.
///
/// [scriptedFailures] makes a call throw once and then succeed, which is how the
/// "lost response" and "lost acknowledgement response" cases are reproduced.
class FakeRelayRepository implements RelayRepository {
  FakeRelayRepository();

  /// Messages accepted, keyed by `client_message_id`. This is the store that
  /// makes a duplicate send resolvable.
  final Map<String, RelayEnvelope> accepted = {};

  /// Ack batches received, in order.
  final List<({List<String> messageIds, String deviceId})> ackCalls = [];

  final List<String> readCalls = [];
  final List<String> deleted = [];

  /// Pages returned by [fetchMessagesAfter], consumed in order.
  final List<List<Map<String, dynamic>>> afterPages = [];

  /// Pages returned by [fetchMessagesBefore].
  final List<List<Map<String, dynamic>>> beforePages = [];

  /// Deletion events returned by [fetchDeletionEvents].
  List<RelayDeletionEvent> deletionEvents = [];

  /// Throw once, then behave normally.
  final Map<String, int> scriptedFailures = {};

  /// When set, every call throws this instead of doing any work.
  Object? hardFailure;

  int sendCalls = 0;
  int afterCalls = 0;

  /// Fails the next call to [name] exactly [times] times.
  void failNext(String name, Object error, {int times = 1}) {
    scriptedFailures[name] = times;
  }

  void _maybeFail(String name) {
    if (hardFailure != null) throw hardFailure!;
    final remaining = scriptedFailures[name];
    if (remaining == null || remaining <= 0) return;
    if (remaining == 1) {
      scriptedFailures.remove(name);
    } else {
      scriptedFailures[name] = remaining - 1;
    }
    throw RelayException('$name scripted failure', RelayFailureKind.transport);
  }

  @override
  Future<RelaySendResult> sendMessage(RelaySendRequest request) async {
    _maybeFail('send_message');
    sendCalls++;

    final existing = accepted[request.clientMessageId];
    if (existing != null) {
      return RelaySendResult(
        envelope: existing,
        outcome: SendOutcome.recovered,
      );
    }

    // The server mints the row id; the client id stays the idempotency key.
    final envelope = RelayEnvelope(
      id: 'srv-${request.clientMessageId}',
      clientMessageId: request.clientMessageId,
      conversationId: request.conversationId,
      senderId: 'me',
      type: request.type,
      payload: request.payload,
      mediaJson: request.media == null ? null : _encode(request.media!),
      media: request.media,
      replyToMessageId: request.replyToMessageId,
      forwarded: request.forwarded,
      serverCreatedAt: DateTime.utc(2026, 1, 1),
    );
    accepted[request.clientMessageId] = envelope;
    return RelaySendResult(envelope: envelope, outcome: SendOutcome.stored);
  }

  @override
  Future<RelayAckResult> acknowledgeDelivered({
    required List<String> messageIds,
    required String deviceId,
  }) async {
    // Recorded BEFORE the scripted failure, because a real server would have
    // received the request and applied it before the response was lost. That is
    // exactly the case the client has to replay safely, so hiding it behind the
    // failure would make the fake untestable for the scenario it exists for.
    ackCalls.add((messageIds: messageIds, deviceId: deviceId));
    _maybeFail('acknowledge_messages');
    return RelayAckResult(
      accepted: messageIds.length,
      rejected: 0,
      deviceId: deviceId,
    );
  }

  @override
  Future<RelayReadResult> markRead({
    required String conversationId,
    required String deviceId,
    String? upToMessageId,
  }) async {
    _maybeFail('mark_read');
    readCalls.add(upToMessageId ?? '<whole conversation>');
    return RelayReadResult(marked: 1, deviceId: deviceId);
  }

  @override
  Future<RelayPage> fetchMessagesAfter({
    required String conversationId,
    String? afterMessageId,
    int limit = 100,
  }) async {
    _maybeFail('get_messages_after');
    afterCalls++;
    if (afterPages.isEmpty) return const RelayPage(envelopes: [], rejected: 0);
    return RelayEnvelope.parsePage(afterPages.removeAt(0));
  }

  @override
  Future<RelayPage> fetchMessagesBefore({
    required String conversationId,
    String? beforeIso,
    int limit = 50,
  }) async {
    _maybeFail('get_messages');
    if (beforePages.isEmpty) return const RelayPage(envelopes: [], rejected: 0);
    return RelayEnvelope.parsePage(beforePages.removeAt(0));
  }

  @override
  Future<List<RelayDeletionEvent>> fetchDeletionEvents({
    DateTime? sinceIso,
    int limit = 200,
  }) async {
    _maybeFail('fetch_deletions_since');
    // A cursor-bounded read, like the real one: only newer events come back.
    if (sinceIso == null) return deletionEvents;
    return deletionEvents.where((e) => e.deletedAt.isAfter(sinceIso)).toList();
  }

  @override
  Future<bool> deleteMessage({
    required String messageId,
    DeletionScope scope = DeletionScope.everyone,
  }) async {
    _maybeFail('delete_message');
    if (!deleted.contains(messageId)) deleted.add(messageId);
    return true;
  }

  static String _encode(Map<String, dynamic> media) {
    // Minimal, dependency-free encoding: the fake only needs the keys back.
    return media.entries.map((e) => '${e.key}=${e.value}').join('&');
  }
}

/// A server row in the shape [RelayEnvelope.tryParse] expects.
///
/// Deliberately a plain map rather than a builder: several tests need a row
/// that is malformed on purpose, and constructing the good version as a map
/// keeps "what the server actually sent" visible in the test.
Map<String, dynamic> relayRow({
  required String id,
  String? clientMessageId,
  required String conversationId,
  required String senderId,
  String? recipientId,
  String type = 'text',
  String? text,
  Map<String, dynamic>? media,
  String? replyToMessageId,
  bool forwarded = false,
  DateTime? createdAt,
  DateTime? deliveredAt,
  DateTime? readAt,
  DateTime? deletedAt,
  String retention = 'retained',
  List<Map<String, dynamic>> reactions = const [],
}) {
  return {
    'id': id,
    'client_message_id': clientMessageId ?? id,
    'conversation_id': conversationId,
    'sender_id': senderId,
    if (recipientId != null) 'recipient_id': recipientId,
    'type': type,
    'text': text,
    'media': media,
    'reply_to_message_id': replyToMessageId,
    'forwarded': forwarded,
    'created_at': (createdAt ?? DateTime.utc(2026, 1, 1)).toIso8601String(),
    'delivered_at': deliveredAt?.toIso8601String(),
    'read_at': readAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'retention_state': retention,
    'schema_version': 1,
    'reactions': reactions,
  };
}
