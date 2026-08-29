import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageType { text, image, video, audio, file, location, contact, sticker, system }

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'sender_id') required String senderId,
    String? content,
    @JsonKey(name: 'message_type') @Default(MessageType.text) MessageType messageType,
    @JsonKey(name: 'reply_to_id') String? replyToId,
    @JsonKey(name: 'forwarded_from_id') String? forwardedFromId,
    @Default(false) bool isDeleted,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'delivered_at') DateTime? deliveredAt,
    @JsonKey(name: 'read_at') DateTime? readAt,
    Map<String, dynamic>? metadata,
    @JsonKey(name: 'reply_to') Message? replyTo,
    List<Attachment>? attachments,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}

@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    @JsonKey(name: 'message_id') required String messageId,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'file_size') required int fileSize,
    @JsonKey(name: 'mime_type') required String mimeType,
    required String url,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    int? duration,
    int? width,
    int? height,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
}
