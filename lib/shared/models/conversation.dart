import '../../../shared/utils/date_time_parser.dart';
import 'user_profile.dart';

/// A conversation row with peer(s) + last message preview as returned by
/// the `get_my_chats` RPC.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    this.isGroup = false,
    this.peer,
    this.peers = const [],
    this.displayName = '',
    this.lastMessageId,
    this.lastMessageText,
    this.lastMessageType = 'text',
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessageLocalState,
    this.lastMessageRemoteStatus,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final peer = UserProfile(
      id: json['peer_id'] as String? ?? '',
      displayName: json['peer_display_name'] as String? ?? '',
      phone: json['peer_phone'] as String? ?? '',
      avatarUrl: json['peer_avatar_url'] as String?,
      presence: json['peer_presence'] as String? ?? 'offline',
      lastSeenAt: parseSupabaseDate(json['peer_last_seen_at']),
    );
    final isGroup = (json['is_group'] as bool?) ?? false;
    final membersRaw = json['members'] as List?;
    final members = <UserProfile>[
      if (peer.id.isNotEmpty) peer,
      ...?membersRaw?.whereType<Map>().map(
        (m) => UserProfile.fromJson(Map<String, dynamic>.from(m)),
      ),
    ];
    return ConversationSummary(
      id: json['conversation_id'] as String,
      isGroup: isGroup,
      peer: peer.id.isEmpty ? null : peer,
      peers: members,
      displayName:
          json['display_name'] as String? ??
          (json['peer_display_name'] as String? ?? ''),
      lastMessageId: json['last_message_id'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageType: json['last_message_type'] as String? ?? 'text',
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: parseSupabaseDate(json['last_message_created_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final bool isGroup;

  /// The direct peer for 1:1 conversations (`null` for groups).
  final UserProfile? peer;

  /// All visible participants (groups may have several).
  final List<UserProfile> peers;

  /// Group/override display name; falls back to the peer name for 1:1.
  final String displayName;

  final String? lastMessageId;
  final String? lastMessageText;
  final String lastMessageType;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// Delivery state of the newest message for the traffic-light preview dot.
  /// Populated from the local cache (never from the RPC). `null` when the last
  /// message is incoming.
  final String? lastMessageLocalState;
  final String? lastMessageRemoteStatus;

  String get title {
    if (displayName.isNotEmpty) return displayName;
    return peer?.displayName ?? 'Conversation';
  }

  String? get avatarKey =>
      peer?.avatarUrl ?? (peers.isNotEmpty ? peers.first.avatarUrl : null);

  ConversationSummary copyWith({
    int? unreadCount,
    String? lastMessageLocalState,
    String? lastMessageRemoteStatus,
  }) {
    return ConversationSummary(
      id: id,
      isGroup: isGroup,
      peer: peer,
      peers: peers,
      displayName: displayName,
      lastMessageId: lastMessageId,
      lastMessageText: lastMessageText,
      lastMessageType: lastMessageType,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageLocalState:
          lastMessageLocalState ?? this.lastMessageLocalState,
      lastMessageRemoteStatus:
          lastMessageRemoteStatus ?? this.lastMessageRemoteStatus,
    );
  }
}
