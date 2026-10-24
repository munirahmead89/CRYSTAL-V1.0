import 'dart:convert';

import '../../../shared/utils/date_time_parser.dart';
import 'message_lifecycle.dart';

/// Outcome of a `send_message` attempt.
///
/// Distinguishes "the server just stored this" from "the server already had
/// this" so the caller can log a retry-resolution separately from a first
/// delivery. Both are success: a duplicate is the expected outcome when a
/// response was lost, not an error.
enum SendOutcome {
  /// First durable server acceptance.
  stored,

  /// The `client_message_id` was already stored; the existing row was
  /// returned. Means a previous attempt committed and its response was lost.
  recovered;

  static SendOutcome fromDuplicate(bool duplicate) =>
      duplicate ? SendOutcome.recovered : SendOutcome.stored;
}

/// The wire representation of one message as the relay returns it.
///
/// Parsing is total: a malformed row, a missing optional field, an unknown
/// schema version or an unrecognised message type all produce a usable
/// envelope rather than an exception. A single unreadable row must never take
/// down a chat screen, so every field falls back and the caller decides
/// whether to keep or drop the row.
class RelayEnvelope {
  const RelayEnvelope({
    required this.id,
    required this.clientMessageId,
    required this.conversationId,
    required this.senderId,
    this.recipientId,
    this.type = RelayMessageType.text,
    this.payload,
    this.ciphertext,
    this.media,
    this.replyToMessageId,
    this.forwarded = false,
    this.mediaJson,
    required this.serverCreatedAt,
    this.serverUpdatedAt,
    this.editedAt,
    this.deliveredAt,
    this.readAt,
    this.deletedAt,
    this.deletedBy,
    this.retention = RetentionState.retained,
    this.schemaVersion = RelaySchemaVersion.current,
    this.encryptionVersion = EncryptionVersion.none,
    this.reactions = const [],
  });

  /// Server-assigned identity. Authoritative for ordering and retention.
  final String id;

  /// Client-assigned identity, minted before the first upload and reused by
  /// every retry. This is the idempotency key.
  final String clientMessageId;

  final String conversationId;
  final String senderId;

  /// Resolved at send time for direct conversations so retention can be
  /// evaluated without re-deriving membership. Null for groups.
  final String? recipientId;

  final RelayMessageType type;

  /// The relay body. Opaque to the server when [encryptionVersion] is not
  /// [EncryptionVersion.none].
  final String? payload;

  final List<int>? ciphertext;

  /// Attachment metadata as a decoded map. Kept alongside [mediaJson] so a
  /// caller that wants the structured form does not have to re-parse, and so
  /// the wire text can be stored verbatim next to the local row.
  final Map<String, dynamic>? media;

  final String? replyToMessageId;
  final bool forwarded;

  /// Attachment metadata as JSON text, kept in the envelope's wire form so the
  /// relay never has to interpret it. `null` for a text message, and `null` for
  /// a deleted message whose payload has already been purged.
  final String? mediaJson;

  /// Server receipt time. Authoritative for ordering; never supplied by the
  /// client.
  final DateTime serverCreatedAt;

  final DateTime? serverUpdatedAt;
  final DateTime? editedAt;

  /// Summary of recipient acknowledgement. The per-device rows behind it are
  /// the truth; this is a denormalisation the sender reads.
  final DateTime? deliveredAt;

  final DateTime? readAt;

  /// Set when the message was deleted for everyone. The payload is already
  /// null at this point, which is why [payload] being absent and [deletedAt]
  /// being present is a normal, renderable combination.
  final DateTime? deletedAt;

  final String? deletedBy;
  final RetentionState retention;
  final RelaySchemaVersion schemaVersion;
  final EncryptionVersion encryptionVersion;
  final List<RelayReaction> reactions;

  bool get isDeleted => deletedAt != null;

  /// True when the server has dropped the payload but kept the row. The row is
  /// what makes a late retry resolve to "already sent" rather than creating a
  /// second message.
  bool get payloadIsPurged =>
      retention == RetentionState.payloadPurged ||
      ciphertext == null && payload == null;

  /// The state this envelope represents for an outgoing message, derived
  /// rather than read from a single mutable status column.
  DeliveryState get derivedState {
    if (isDeleted) return DeliveryState.deleted;
    if (readAt != null) return DeliveryState.read;
    if (deliveredAt != null) return DeliveryState.delivered;
    return DeliveryState.sent;
  }

  /// Total, non-throwing decoder.
  ///
  /// [requiredKeys] is the list of columns the server must have provided for
  /// the row to be usable at all; a row missing one of them is rejected so the
  /// caller can skip it instead of storing a message with a blank id.
  static RelayEnvelope? tryParse(
    Map<String, dynamic> json, {
    Set<String> requiredKeys = const {'id', 'conversation_id', 'sender_id'},
  }) {
    for (final key in requiredKeys) {
      final value = json[key];
      if (value is! String || value.isEmpty) return null;
    }

    final createdAt = parseSupabaseDate(json['created_at']) ?? DateTime.now();

    return RelayEnvelope(
      id: json['id'] as String,
      clientMessageId:
          (json['client_message_id'] as String?) ?? json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      recipientId: json['recipient_id'] as String?,
      // An unknown type degrades to text rather than dropping the message: a
      // newer server must not be able to hide a message from an older client.
      type:
          RelayMessageType.tryParse(json['type'] as String?) ??
          RelayMessageType.text,
      payload: (json['text'] as String?) ?? (json['content'] as String?),
      ciphertext: _decodeCiphertext(json['ciphertext']),
      // The 00030 schema named this `reply_to_id`; both spellings are read so
      // a database built from either base decodes correctly.
      replyToMessageId:
          (json['reply_to_message_id'] as String?) ??
          (json['reply_to_id'] as String?),
      forwarded: json['forwarded'] == true,
      mediaJson: json['media'] is Map
          ? jsonEncode(Map<String, dynamic>.from(json['media'] as Map))
          : (json['media'] as String?),
      media: json['media'] is Map
          ? Map<String, dynamic>.from(json['media'] as Map)
          : null,
      serverCreatedAt: createdAt,
      serverUpdatedAt: parseSupabaseDate(json['updated_at']),
      editedAt: parseSupabaseDate(json['edited_at']),
      deliveredAt: parseSupabaseDate(json['delivered_at']),
      readAt: parseSupabaseDate(json['read_at']),
      deletedAt: parseSupabaseDate(json['deleted_at']),
      deletedBy: json['deleted_by'] as String?,
      retention: RetentionState.fromString(json['retention_state'] as String?),
      schemaVersion: RelaySchemaVersion.fromInt(
        (json['schema_version'] as num?)?.toInt(),
      ),
      encryptionVersion: EncryptionVersion.fromInt(
        (json['encryption_version'] as num?)?.toInt(),
      ),
      reactions: _decodeReactions(json['reactions']),
    );
  }

  /// Decodes a page of rows, skipping any that cannot be read.
  ///
  /// Returns what was usable together with the count that was dropped, so the
  /// caller can surface a real problem instead of silently losing messages.
  static RelayPage parsePage(Object? raw) {
    if (raw is! List) return const RelayPage(envelopes: [], rejected: 0);

    final envelopes = <RelayEnvelope>[];
    var rejected = 0;
    for (final row in raw) {
      if (row is! Map) {
        rejected++;
        continue;
      }
      final envelope = tryParse(Map<String, dynamic>.from(row));
      if (envelope == null) {
        rejected++;
        continue;
      }
      envelopes.add(envelope);
    }
    return RelayPage(envelopes: envelopes, rejected: rejected);
  }

  static List<int>? _decodeCiphertext(Object? raw) {
    // Postgres returns bytea as the `\\xDEADBEEF` hex string.
    if (raw is String && raw.startsWith('\\x')) {
      final hex = raw.substring(2);
      if (hex.length.isOdd) return null;
      final out = <int>[];
      for (var i = 0; i < hex.length; i += 2) {
        final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
        if (byte == null) return null;
        out.add(byte);
      }
      return out;
    }
    if (raw is List) return raw.map((v) => (v as num).toInt()).toList();
    return null;
  }

  static List<RelayReaction> _decodeReactions(Object? raw) {
    if (raw is! List) return const [];
    final out = <RelayReaction>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final userId = item['user_id'];
      final emoji = item['emoji'];
      if (userId is! String || emoji is! String) continue;
      out.add(
        RelayReaction(
          userId: userId,
          emoji: emoji,
          createdAt: parseSupabaseDate(item['created_at']),
        ),
      );
    }
    return out;
  }
}

/// A page of envelopes plus the number of rows that could not be read.
///
/// [rejected] is reported rather than swallowed: a permanently non-zero value
/// means the server is sending something this build does not understand.
class RelayPage {
  const RelayPage({required this.envelopes, required this.rejected});

  final List<RelayEnvelope> envelopes;
  final int rejected;

  bool get isEmpty => envelopes.isEmpty;
  int get length => envelopes.length;
}

/// One reaction stamp on a relay message.
class RelayReaction {
  const RelayReaction({
    required this.userId,
    required this.emoji,
    this.createdAt,
  });

  final String userId;
  final String emoji;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'emoji': emoji,
    if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
  };
}

/// Result of a durable send, as returned by the relay.
class RelaySendResult {
  const RelaySendResult({required this.envelope, required this.outcome});

  final RelayEnvelope envelope;
  final SendOutcome outcome;

  bool get isRecovery => outcome == SendOutcome.recovered;
}

/// Result of a delivery acknowledgement batch.
class RelayAckResult {
  const RelayAckResult({this.accepted = 0, this.rejected = 0, this.deviceId});

  /// Messages this device's acknowledgement is now recorded for.
  final int accepted;

  /// Messages the server did not accept. Either not accessible to this user,
  /// not in this conversation, or truncated by the server's per-call bound.
  final int rejected;

  final String? deviceId;

  static RelayAckResult parse(Object? raw) {
    if (raw is! Map) return const RelayAckResult();
    return RelayAckResult(
      accepted: (raw['accepted'] as num?)?.toInt() ?? 0,
      rejected: (raw['rejected'] as num?)?.toInt() ?? 0,
      deviceId: raw['device_id'] as String?,
    );
  }
}

/// Result of a read-receipt batch.
class RelayReadResult {
  const RelayReadResult({this.marked = 0, this.deviceId});

  final int marked;
  final String? deviceId;

  static RelayReadResult parse(Object? raw) {
    if (raw is! Map) return const RelayReadResult();
    return RelayReadResult(
      marked: (raw['marked'] as num?)?.toInt() ?? 0,
      deviceId: raw['device_id'] as String?,
    );
  }
}

/// A durable deletion event.
///
/// Tombstones are timestamped and versioned rather than being a "delete this
/// id" flag on the message row, because a client that was offline for a week
/// must be able to learn about deletions it never saw happen, and because
/// ordering two of these against a concurrent sync needs something
/// monotonic to compare.
class RelayDeletionEvent {
  const RelayDeletionEvent({
    required this.messageId,
    required this.conversationId,
    required this.actorId,
    required this.deletedAt,
    this.scope = DeletionScope.everyone,
    this.payloadVersion = 1,
  });

  final String messageId;
  final String conversationId;
  final String actorId;
  final DateTime deletedAt;
  final DeletionScope scope;
  final int payloadVersion;

  /// Total, non-throwing decoder. A row without a message id cannot be
  /// applied and is rejected by the caller.
  static RelayDeletionEvent? tryParse(Map<String, dynamic> json) {
    final messageId = json['message_id'];
    final conversationId = json['conversation_id'];
    if (messageId is! String || messageId.isEmpty) return null;
    if (conversationId is! String || conversationId.isEmpty) return null;

    final deletedAt = parseSupabaseDate(json['deleted_at']);
    if (deletedAt == null) return null;

    return RelayDeletionEvent(
      messageId: messageId,
      conversationId: conversationId,
      actorId: json['actor_id'] as String? ?? '',
      deletedAt: deletedAt,
      scope: DeletionScope.fromString(json['scope'] as String?),
      payloadVersion: (json['payload_version'] as num?)?.toInt() ?? 1,
    );
  }

  static List<RelayDeletionEvent> parseList(Object? raw) {
    if (raw is! List) return const [];
    final out = <RelayDeletionEvent>[];
    for (final row in raw) {
      if (row is! Map) continue;
      final event = tryParse(Map<String, dynamic>.from(row));
      if (event != null) out.add(event);
    }
    return out;
  }
}

/// Request body for `send_message`.
///
/// Encapsulated so the parameter set of a security-relevant call is one named
/// object rather than ten positional arguments at every call site.
class RelaySendRequest {
  const RelaySendRequest({
    required this.conversationId,
    required this.clientMessageId,
    this.type = RelayMessageType.text,
    this.payload,
    this.media,
    this.replyToMessageId,
    this.forwarded = false,
    this.schemaVersion = RelaySchemaVersion.current,
    this.ciphertext,
    this.encryptionVersion,
  });

  final String conversationId;

  /// The idempotency key. Stable across every retry of the same composition.
  final String clientMessageId;

  final RelayMessageType type;
  final String? payload;
  final Map<String, dynamic>? media;
  final String? replyToMessageId;
  final bool forwarded;
  final RelaySchemaVersion schemaVersion;
  final List<int>? ciphertext;
  final EncryptionVersion? encryptionVersion;

  Map<String, dynamic> toRpcParams() => {
    'p_conversation_id': conversationId,
    'p_client_message_id': clientMessageId,
    'p_message_type': type.wireValue,
    if (payload != null) 'p_text': payload,
    if (media != null) 'p_media': media,
    if (replyToMessageId != null) 'p_reply_to_message_id': replyToMessageId,
    'p_forwarded': forwarded,
    'p_schema_version': schemaVersion.value,
    if (ciphertext != null) 'p_ciphertext': _hex(ciphertext!),
    if (encryptionVersion != null)
      'p_encryption_version': encryptionVersion!.value,
  };

  static String _hex(List<int> bytes) =>
      '\\x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

/// Serialisation of the acknowledgement ledger kept on the device.
///
/// The ledger is what makes an acknowledgement both durable and idempotent:
/// it records what THIS device has already reported, so a lost response
/// causes a replay (harmless, `ON CONFLICT DO NOTHING` on the server) rather
/// than a permanently false "delivered".
class AckLedgerEntry {
  const AckLedgerEntry({
    required this.messageId,
    required this.kind,
    required this.reported,
    this.reportedAt,
    this.attempts = 0,
  });

  final String messageId;
  final AckKind kind;

  /// True once the server has acknowledged our acknowledgement.
  final bool reported;

  final DateTime? reportedAt;
  final int attempts;

  Map<String, dynamic> toJson() => {
    'message_id': messageId,
    'kind': kind.name,
    'reported': reported,
    if (reportedAt != null)
      'reported_at': reportedAt!.toUtc().toIso8601String(),
    'attempts': attempts,
  };

  static AckLedgerEntry? tryParse(Map<String, dynamic> json) {
    final messageId = json['message_id'];
    if (messageId is! String || messageId.isEmpty) return null;
    return AckLedgerEntry(
      messageId: messageId,
      kind: AckKind.fromString(json['kind'] as String?),
      reported: json['reported'] == true,
      reportedAt: parseSupabaseDate(json['reported_at']),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());
}
