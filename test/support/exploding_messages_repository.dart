import 'package:crystal_messenger/features/conversations/domain/repositories/chat_repositories.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';

/// Fails any call, so a test can prove the trusted relay path is the one being
/// exercised rather than a legacy fallback.
///
/// The outbox keeps [MessagesRepository] only for backwards compatibility with
/// callers that have not injected a relay. In every test that injects one, the
/// legacy path must be unreachable; a stub that throws turns that into an
/// assertion rather than an assumption.
class ExplodingMessagesRepository implements MessagesRepository {
  const ExplodingMessagesRepository();

  Never _fail(String method) => throw StateError(
    'MessagesRepository.$method was called, but the trusted relay path '
    'should have been used instead.',
  );

  @override
  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async => _fail('getMessages');

  @override
  Future<List<ChatMessage>> getMessagesAfter(
    String conversationId, {
    required String? afterId,
    int limit = 100,
  }) async => _fail('getMessagesAfter');

  @override
  Future<ChatMessage> send(ChatMessage draft) async => _fail('send');

  @override
  Future<List<MessageReaction>> setReaction({
    required String messageId,
    String? emoji,
  }) async => _fail('setReaction');

  @override
  Future<void> editText({
    required String messageId,
    required String body,
  }) async => _fail('editText');
}
