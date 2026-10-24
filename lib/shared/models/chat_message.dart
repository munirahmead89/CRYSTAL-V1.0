import '../../../shared/utils/date_time_parser.dart';

/// Attached metadata for media-bearing messages.
///
/// Carries either a plain [url] (legacy single-object media) or the
/// coordinates of a chunked transfer ([uploadId] + geometry + [sha256]).
/// The chunked form is what lets a multi-gigabyte video be sent through a
/// backend that only accepts 6 MB objects, and still arrive as one intact,
/// playable file.
class Attachment {
  const Attachment({
    this.name,
    this.url,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.uploadId,
    this.partCount,
    this.partBytes,
    this.sha256,
    this.localPath,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      name: json['name'] as String?,
      url: json['url'] as String?,
      mimeType: json['mime_type'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      uploadId: json['upload_id'] as String?,
      partCount: (json['part_count'] as num?)?.toInt(),
      partBytes: (json['part_bytes'] as num?)?.toInt(),
      sha256: json['sha256'] as String?,
      localPath: json['local_path'] as String?,
    );
  }

  final String? name;

  /// Direct URL. Present only for legacy single-object media; chunked
  /// attachments deliberately have no public URL.
  final String? url;

  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;

  /// Id of the `media_uploads` manifest for a chunked attachment.
  final String? uploadId;

  /// Number of parts the file was split into.
  final int? partCount;

  /// Size of every part except the last.
  final int? partBytes;

  /// SHA-256 of the whole original file, verified after reassembly.
  final String? sha256;

  /// Absolute path of the ORIGINAL file on this device, for an attachment that
  /// has been composed but not yet uploaded.
  ///
  /// This is what makes offline media queueing possible: the message and its
  /// bytes are both captured locally while offline, and the outbox uploads
  /// from here once the network returns. Never serialised to the server.
  final String? localPath;

  /// True when this attachment has been composed but is still waiting to be
  /// uploaded.
  bool get isPendingUpload =>
      (localPath?.isNotEmpty ?? false) &&
      (uploadId == null || uploadId!.isEmpty);

  /// True when this attachment is stored as ordered parts rather than one
  /// object.
  bool get isChunked => (uploadId?.isNotEmpty ?? false) && (partCount ?? 0) > 0;

  /// True when the file is large enough that auto-download would burn the
  /// free tier's 5 GB/month egress allowance. WhatsApp behaves the same way:
  /// big media is fetched only on demand.
  bool get isLarge => (sizeBytes ?? 0) > 8 * 1024 * 1024;

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'width': width,
    'height': height,
    'duration_ms': durationMs,
    if (uploadId != null) 'upload_id': uploadId,
    if (partCount != null) 'part_count': partCount,
    if (partBytes != null) 'part_bytes': partBytes,
    if (sha256 != null) 'sha256': sha256,
    // Local only: the outbox needs it, the server must never see it.
    if (localPath != null) 'local_path': localPath,
  };

  /// The subset the server is allowed to see.
  ///
  /// Strips [localPath] so a device-local filesystem path is never written to
  /// a row other participants can read.
  Map<String, dynamic> toServerJson() {
    final json = toJson()..remove('local_path');
    return json;
  }

  Attachment copyWith({String? url, String? localPath, int? durationMs}) =>
      Attachment(
        name: name,
        url: url ?? this.url,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        width: width,
        height: height,
        // Overridable so a measured voice-note length can be folded in; the
        // previous signature accepted a duration at the call site but had no
        // way to apply it, so the value was silently discarded.
        durationMs: durationMs ?? this.durationMs,
        uploadId: uploadId,
        partCount: partCount,
        partBytes: partBytes,
        sha256: sha256,
        localPath: localPath ?? this.localPath,
      );
}

/// A single stamp a user placed on a message (Messenger-style reactions).
class MessageReaction {
  const MessageReaction({
    required this.userId,
    required this.emoji,
    this.createdAt,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      userId: json['user_id'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      createdAt: parseSupabaseDate(json['created_at']),
    );
  }

  final String userId;
  final String emoji;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'emoji': emoji,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

const _allowedMessageTypes = {
  'text',
  'image',
  'file',
  'voice',
  'video',
  'system',
};

/// Local delivery state of a message.
enum MessageLocalState {
  local,
  queued,
  sending,
  sent,
  failed;

  static MessageLocalState fromString(String? value) =>
      MessageLocalState.values.firstWhere(
        (s) => s.name == value,
        orElse: () => MessageLocalState.local,
      );
}

/// Server-side delivery state reported via message receipts.
enum RemoteStatus {
  sent,
  delivered,
  seen;

  static RemoteStatus fromString(String? value) => RemoteStatus.values
      .firstWhere((s) => s.name == value, orElse: () => RemoteStatus.sent);
}

/// A single chat message (server row + local sync state).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.clientMessageId,
    required this.conversationId,
    required this.senderId,
    this.type = 'text',
    this.body,
    this.attachment,
    this.reactions = const [],
    this.replyToId,
    this.forwarded = false,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    this.outgoing = false,
    this.localState = MessageLocalState.sent,
    this.remoteStatus = RemoteStatus.sent,
    this.deliveredAt,
    this.readAt,
  });

  factory ChatMessage.fromServerJson(
    Map<String, dynamic> json, {
    String? myUserId,
    MessageLocalState localState = MessageLocalState.sent,
  }) {
    final type = json['type'] as String? ?? 'text';
    final mediaJson = json['media'];
    final reactionsRaw = json['reactions'];
    return ChatMessage(
      id: json['id'] as String,
      clientMessageId:
          json['client_message_id'] as String? ?? json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      type: _allowedMessageTypes.contains(type) ? type : 'text',
      body: json['text'] as String?,
      attachment: mediaJson is Map<String, dynamic>
          ? Attachment.fromJson(mediaJson)
          : null,
      reactions: reactionsRaw is List
          ? reactionsRaw
                .whereType<Map>()
                .map(
                  (r) => MessageReaction.fromJson(Map<String, dynamic>.from(r)),
                )
                .toList()
          : const [],
      replyToId:
          json['reply_to_message_id'] as String? ??
          json['reply_to_id'] as String?,
      forwarded: json['forwarded'] == true,
      createdAt: parseSupabaseDate(json['created_at']) ?? DateTime.now(),
      editedAt: parseSupabaseDate(json['edited_at']),
      deleted: json['deleted_at'] != null || json['deleted'] == true,
      outgoing: myUserId != null && myUserId == json['sender_id'],
      localState: localState,
      deliveredAt: parseSupabaseDate(json['delivered_at']),
      readAt: parseSupabaseDate(json['read_at']),
    );
  }

  final String id;
  final String clientMessageId;
  final String conversationId;
  final String senderId;
  final String type;
  final String? body;
  final Attachment? attachment;
  final List<MessageReaction> reactions;
  final String? replyToId;

  /// True when this message was forwarded rather than composed here.
  ///
  /// Read by the receiver as well as the sender: a forwarded photo shown
  /// with no marker reads as original, which is exactly how forwarded
  /// misinformation spreads.
  final bool forwarded;

  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final bool outgoing;
  final MessageLocalState localState;
  final RemoteStatus remoteStatus;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get isMedia =>
      type == 'image' || type == 'file' || type == 'voice' || type == 'video';

  ChatMessage copyWith({
    MessageLocalState? localState,
    RemoteStatus? remoteStatus,
    bool? deleted,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? body,
    DateTime? editedAt,
    List<MessageReaction>? reactions,
  }) {
    return ChatMessage(
      id: id,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      // `?? this.body` rather than `body ?? this.body`: an edit that clears the
      // body has to be representable, and the server rejects an empty body
      // anyway, so "absent" and "cleared" never differ in practice.
      body: body ?? this.body,
      attachment: attachment,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId,
      forwarded: forwarded,
      createdAt: createdAt,
      deleted: deleted ?? this.deleted,
      outgoing: outgoing,
      localState: localState ?? this.localState,
      remoteStatus: remoteStatus ?? this.remoteStatus,
      editedAt: editedAt ?? this.editedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Grouped `emoji -> count`, used by bubble chips and the picker.
  Map<String, int> reactionCounts() {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  bool hasReacted(String emoji, String myUserId) =>
      reactions.any((r) => r.userId == myUserId && r.emoji == emoji);
}
