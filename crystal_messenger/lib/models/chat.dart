import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

enum ChatType { direct, group, channel }

@freezed
class Chat with _$Chat {
  const factory Chat({
    required String id,
    @JsonKey(name: 'type') required ChatType chatType,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'is_encrypted') @Default(false) bool isEncrypted,
    @JsonKey(name: 'disappearing_timer') @Default(0) int disappearingTimer,
    @JsonKey(name: 'last_message_content') String? lastMessageContent,
    @JsonKey(name: 'last_message_at') DateTime? lastMessageAt,
    @JsonKey(name: 'unread_count') @Default(0) int unreadCount,
    @JsonKey(name: 'other_user') UserProfile? otherUser,
    String? name,
    String? avatarUrl,
  }) = _Chat;

  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);
}

// Need to import UserProfile or define it inline
// For now, define a minimal version
@freezed
class _UserProfile with _$_UserProfile {
  const factory _UserProfile({
    required String id,
    String? fullName,
    String? avatarUrl,
  }) = _UserProfile;
}
