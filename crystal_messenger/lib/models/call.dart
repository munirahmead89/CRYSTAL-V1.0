import 'package:freezed_annotation/freezed_annotation.dart';

part 'call.freezed.dart';
part 'call.g.dart';

enum CallType { audio, video }
enum CallStatus { ringing, active, missed, declined, ended }

@freezed
class Call with _$Call {
  const factory Call({
    required String id,
    @JsonKey(name: 'chat_id') String? chatId,
    @JsonKey(name: 'caller_id') required String callerId,
    @JsonKey(name: 'call_type') required CallType callType,
    required CallStatus status,
    @JsonKey(name: 'started_at') required DateTime startedAt,
    @JsonKey(name: 'ended_at') DateTime? endedAt,
    int? duration,
    UserProfile? caller,
  }) = _Call;

  factory Call.fromJson(Map<String, dynamic> json) => _$CallFromJson(json);
}

@freezed
class CallParticipant with _$CallParticipant {
  const factory CallParticipant({
    required String id,
    @JsonKey(name: 'call_id') required String callId,
    @JsonKey(name: 'user_id') required String userId,
    required String status,
    @JsonKey(name: 'joined_at') DateTime? joinedAt,
  }) = _CallParticipant;

  factory CallParticipant.fromJson(Map<String, dynamic> json) =>
      _$CallParticipantFromJson(json);
}
