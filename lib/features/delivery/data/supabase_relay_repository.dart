import 'package:supabase_flutter/supabase_flutter.dart';

import '../../delivery/domain/repositories/relay_repository.dart';
import '../domain/message_lifecycle.dart';
import '../domain/relay_failure.dart';
import '../domain/relay_envelope.dart';

/// Talks to the relay's trusted server functions.
///
/// Every call goes through an RPC rather than a table write. That is the whole
/// security boundary: the client holds an anon key, so the server has to be the
/// one validating conversation membership, device ownership, rate limits and
/// payload size. Nothing here trusts an identifier the client supplied.
///
/// Failures surface as [RelayException] rather than as raw `PostgrestException`
/// so callers can distinguish "try again" from "this will never work" without
/// string-matching a server error message.
class SupabaseRelayRepository implements RelayRepository {
  SupabaseRelayRepository(this._client);

  final SupabaseClient _client;

  /// Server-side per-call ceilings. Requesting more is pointless: the server
  /// truncates, and the client would then advance a cursor past rows it never
  /// received.
  static const int maxSyncPage = 200;
  static const int maxAckBatch = 200;
  static const int maxDeletionPage = 200;

  @override
  Future<RelaySendResult> sendMessage(RelaySendRequest request) async {
    final raw = await _call(
      'send_message',
      request.toRpcParams(),
      // A lost response is exactly the case send_message is idempotent for.
      // The outbox retries with the same client_message_id, so this is
      // expected to happen rather than exceptional.
      retryable: true,
    );

    final row = raw is Map ? raw['message'] : null;
    final envelope = RelayEnvelope.tryParse(
      row is Map ? Map<String, dynamic>.from(row) : const {},
      requiredKeys: const {'id', 'conversation_id', 'sender_id'},
    );

    if (envelope == null) {
      throw const RelayException(
        'The relay accepted the message but returned an unreadable row.',
        RelayFailureKind.malformedResponse,
      );
    }

    return RelaySendResult(
      envelope: envelope,
      outcome: SendOutcome.fromDuplicate(
        raw is Map && raw['duplicate'] == true,
      ),
    );
  }

  @override
  Future<RelayAckResult> acknowledgeDelivered({
    required List<String> messageIds,
    required String deviceId,
  }) async {
    if (messageIds.isEmpty) return const RelayAckResult();

    // Chunked so one batch can never exceed the server's own per-call bound,
    // which would silently truncate and report the tail as rejected forever.
    var accepted = 0;
    var rejected = 0;

    for (var offset = 0; offset < messageIds.length; offset += maxAckBatch) {
      final end = (offset + maxAckBatch).clamp(0, messageIds.length);
      final chunk = messageIds.sublist(offset, end);

      final raw = await _call('acknowledge_messages', {
        'p_message_ids': chunk,
        'p_device_id': deviceId,
      }, retryable: true);

      final result = RelayAckResult.parse(raw);
      final took = result.accepted.clamp(0, chunk.length);
      accepted += took;
      rejected += (chunk.length - took).clamp(0, chunk.length);
    }

    return RelayAckResult(
      accepted: accepted,
      rejected: rejected,
      deviceId: deviceId,
    );
  }

  @override
  Future<RelayReadResult> markRead({
    required String conversationId,
    required String deviceId,
    String? upToMessageId,
  }) async {
    final raw = await _call('mark_read', {
      'p_conversation': conversationId,
      'p_device_id': deviceId,
      if (upToMessageId != null) 'p_up_to_message_id': upToMessageId,
    }, retryable: true);
    return RelayReadResult.parse(raw);
  }

  @override
  Future<RelayPage> fetchMessagesAfter({
    required String conversationId,
    String? afterMessageId,
    int limit = 100,
  }) async {
    final raw = await _call('get_messages_after', {
      'p_conversation': conversationId,
      if (afterMessageId != null) 'p_after_id': afterMessageId,
      'p_limit': limit.clamp(1, maxSyncPage),
    }, retryable: true);
    return RelayEnvelope.parsePage(raw);
  }

  @override
  Future<RelayPage> fetchMessagesBefore({
    required String conversationId,
    String? beforeIso,
    int limit = 50,
  }) async {
    final raw = await _call('get_messages', {
      'p_conversation': conversationId,
      if (beforeIso != null) 'p_before': beforeIso,
      'p_limit': limit.clamp(1, maxSyncPage),
    }, retryable: true);
    return RelayEnvelope.parsePage(raw);
  }

  @override
  Future<List<RelayDeletionEvent>> fetchDeletionEvents({
    DateTime? sinceIso,
    int limit = maxDeletionPage,
  }) async {
    final raw = await _call('fetch_deletions_since', {
      if (sinceIso != null) 'p_since': sinceIso.toUtc().toIso8601String(),
      'p_limit': limit.clamp(1, maxDeletionPage),
    }, retryable: true);
    return RelayDeletionEvent.parseList(raw);
  }

  @override
  Future<bool> deleteMessage({
    required String messageId,
    DeletionScope scope = DeletionScope.everyone,
  }) async {
    final raw = await _call(
      'delete_message',
      {'p_message_id': messageId, 'p_scope': scope.name},
      // A delete is idempotent server-side, so a retry is safe and expected.
      retryable: true,
    );
    return raw is Map && raw['deleted'] == true;
  }

  /// Single choke point for every relay RPC.
  ///
  /// Classifies the failure rather than letting a raw PostgREST error escape,
  /// because the difference decides whether the caller keeps its row for
  /// another attempt or surfaces a permanent error to the user:
  /// * 401/403 → the session is gone; retry after a refresh.
  /// * 42501/22023/42P01 → the request will never succeed as written.
  /// * 42901    → back off; the rate limiter is doing its job.
  /// * anything else (network, 5xx, socket) → retryable.
  Future<Object?> _call(
    String fn,
    Map<String, dynamic> params, {
    required bool retryable,
  }) async {
    try {
      return await _client.rpc(fn, params: params);
    } on PostgrestException catch (error) {
      throw RelayException(
        _describe(fn, error),
        _classify(error.code, retryable: retryable),
        cause: error,
      );
    } on AuthException catch (error) {
      throw RelayException(
        'Not signed in.',
        RelayFailureKind.unauthenticated,
        cause: error,
      );
    } catch (error) {
      throw RelayException(
        'The relay is unreachable.',
        retryable ? RelayFailureKind.transport : RelayFailureKind.unknown,
        cause: error,
      );
    }
  }

  static RelayFailureKind _classify(String? code, {required bool retryable}) {
    switch (code) {
      case '28000':
      case '42501':
        return RelayFailureKind.unauthorized;
      case '22023':
        return RelayFailureKind.invalidRequest;
      case '42901':
        return RelayFailureKind.rateLimited;
      case '42501 ':
        return RelayFailureKind.unauthorized;
      case '42P01':
        return RelayFailureKind.unavailable;
      default:
        return retryable
            ? RelayFailureKind.transport
            : RelayFailureKind.unknown;
    }
  }

  /// Deliberately reports the RPC name and the SQLSTATE only.
  ///
  /// Server error text is not reproduced: a Postgres message can quote the
  /// offending value, and for a messaging backend that value is frequently the
  /// message body.
  static String _describe(String fn, PostgrestException error) {
    final code = error.code;
    if (code == null || code.isEmpty) return '$fn failed.';
    return '$fn failed ($code).';
  }
}
