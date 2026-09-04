import 'package:freezed_annotation/freezed_annotation.dart';

part 'scheduled_message.freezed.dart';
part 'scheduled_message.g.dart';

@freezed
class ScheduledMessage with _$ScheduledMessage {
  const factory ScheduledMessage({
    required String id,
    @JsonKey(name: 'chat_id') required String chatId,
    required String content,
    @JsonKey(name: 'message_type') @Default('text') String messageType,
    Map<String, dynamic>? metadata,
    @JsonKey(name: 'scheduled_for') required DateTime scheduledFor,
    @JsonKey(name: 'is_sent') @Default(false) bool isSent,
    @JsonKey(name: 'sent_at') DateTime? sentAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _ScheduledMessage;

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) =>
      _$ScheduledMessageFromJson(json);
}
