import 'package:freezed_annotation/freezed_annotation.dart';

part 'poll.freezed.dart';
part 'poll.g.dart';

@freezed
class Poll with _$Poll {
  const factory Poll({
    required String id,
    @JsonKey(name: 'chat_id') required String chatId,
    @JsonKey(name: 'creator_id') required String creatorId,
    required String question,
    @JsonKey(name: 'is_anonymous') @Default(true) bool isAnonymous,
    @JsonKey(name: 'is_multiple_choice') @Default(false) bool isMultipleChoice,
    @JsonKey(name: 'expires_at') DateTime? expiresAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _Poll;

  factory Poll.fromJson(Map<String, dynamic> json) => _$PollFromJson(json);
}

@freezed
class PollOption with _$PollOption {
  const factory PollOption({
    required String id,
    @JsonKey(name: 'poll_id') required String pollId,
    required String text,
    @Default(0) int position,
    @JsonKey(name: 'vote_count') @Default(0) int voteCount,
    @JsonKey(name: 'has_voted') @Default(false) bool hasVoted,
  }) = _PollOption;

  factory PollOption.fromJson(Map<String, dynamic> json) =>
      _$PollOptionFromJson(json);
}

@freezed
class PollResults with _$PollResults {
  const factory PollResults({
    required Poll poll,
    required List<PollOption> options,
    @JsonKey(name: 'total_votes') @Default(0) int totalVotes,
  }) = _PollResults;

  factory PollResults.fromJson(Map<String, dynamic> json) =>
      _$PollResultsFromJson(json);
}
