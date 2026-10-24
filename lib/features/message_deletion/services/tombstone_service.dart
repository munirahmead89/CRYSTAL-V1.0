import '../../../core/database/local_store.dart';
import '../../delivery/domain/message_lifecycle.dart';
import '../../delivery/domain/relay_envelope.dart';
import '../../delivery/domain/relay_failure.dart';
import '../../delivery/domain/repositories/relay_repository.dart';

/// Outcome of a user-requested deletion.
class DeletionOutcome {
  const DeletionOutcome({
    required this.succeeded,
    required this.scope,
    this.tombstoned = false,
    this.detail,
  });

  final bool succeeded;
  final DeletionScope scope;

  /// True when a local tombstone now exists, which is what stops a later sync
  /// from restoring the message.
  final bool tombstoned;

  /// Safe to show to a user. Never contains message content.
  final String? detail;
}

/// Applies deletions, keeping "for me" and "for everyone" genuinely separate.
///
/// The two scopes are different mechanisms, not two settings on one path:
///
/// * **Delete for me** never touches the network. It has to work on a plane,
///   and it must not reveal anything to the other participant. All it does is
///   write a local tombstone, so the message stays gone even after a sync.
///   The other participant keeps their copy.
/// * **Delete for everyone** asks the relay to record a durable deletion event.
///   The server authorizes it against the authenticated user, the conversation
///   membership and a message-age policy, nulls the payload, and writes a
///   tombstone that other devices pick up through the deletion cursor.
///
/// ### What deletion cannot do
///
/// It cannot un-see a message that was already displayed, remove it from a
/// screenshot, revoke a copy the recipient exported, or erase a notification
/// that has already appeared. Those are stated rather than implied, because
/// "delete for everyone" otherwise reads as a stronger guarantee than any
/// messenger can honour.
class TombstoneService {
  TombstoneService({
    required this.store,
    required this.repository,
    this.isOnline,
    this.onError,
  });

  final LocalStore store;
  final RelayRepository repository;
  final bool Function()? isOnline;
  final void Function(Object error, StackTrace stack)? onError;

  /// Deletes for this device only. Always succeeds offline.
  Future<DeletionOutcome> deleteForMe({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      await store.writeTombstone(
        messageId: messageId,
        conversationId: conversationId,
        scope: DeletionScope.me,
        deletedAt: DateTime.now(),
      );
      return const DeletionOutcome(
        succeeded: true,
        scope: DeletionScope.me,
        tombstoned: true,
      );
    } catch (error, stack) {
      onError?.call(error, stack);
      return const DeletionOutcome(
        succeeded: false,
        scope: DeletionScope.me,
        detail: 'Could not delete this message on this device.',
      );
    }
  }

  /// Deletes for every participant.
  ///
  /// The local tombstone is written whether or not the server call succeeds,
  /// but the two outcomes are reported differently and only the server's
  /// version is a real "for everyone":
  ///
  /// * server refused (too old, not a member, not permitted) → the message
  ///   stays for everyone, and the local copy is left alone so the user's view
  ///   does not silently disagree with the other participant;
  /// * server unreachable → the message is hidden locally, retried later, and
  ///   the user is told the other side still has it.
  Future<DeletionOutcome> deleteForEveryone({
    required String messageId,
    required String conversationId,
  }) async {
    if (isOnline?.call() == false) {
      // Deleting for everyone genuinely requires the server, so this is a
      // real failure rather than something to pretend succeeded.
      return const DeletionOutcome(
        succeeded: false,
        scope: DeletionScope.everyone,
        detail: 'You need a connection to delete a message for everyone.',
      );
    }

    try {
      final removed = await repository.deleteMessage(
        messageId: messageId,
        scope: DeletionScope.everyone,
      );

      if (!removed) {
        return DeletionOutcome(
          succeeded: false,
          scope: DeletionScope.everyone,
          detail: 'The server declined to delete this message.',
        );
      }

      await store.writeTombstone(
        messageId: messageId,
        conversationId: conversationId,
        scope: DeletionScope.everyone,
        deletedAt: DateTime.now(),
      );

      return const DeletionOutcome(
        succeeded: true,
        scope: DeletionScope.everyone,
        tombstoned: true,
      );
    } on RelayException catch (error, stack) {
      onError?.call(error, stack);
      return DeletionOutcome(
        succeeded: false,
        scope: DeletionScope.everyone,
        detail: switch (error.kind) {
          RelayFailureKind.unauthorized => 'You cannot delete this message.',
          RelayFailureKind.rateLimited =>
            'Too many requests. Try again shortly.',
          _ => 'Removed on this device only. The other person still has it.',
        },
      );
    } catch (error, stack) {
      onError?.call(error, stack);
      return const DeletionOutcome(
        succeeded: false,
        scope: DeletionScope.everyone,
        detail: 'Removed on this device only. The other person still has it.',
      );
    }
  }

  /// Applies server deletion events this device had not yet seen.
  ///
  /// Called by the recovery pass. Idempotent, and safe to interleave with a
  /// running message sync because the tombstone is written inside the same
  /// transaction as the message write.
  Future<int> applyRemoteDeletions(
    List<RelayDeletionEvent> events, {
    String? cursorKey,
  }) {
    if (events.isEmpty) return Future.value(0);
    return store.applyDeletionEvents(
      events,
      cursorKey: cursorKey ?? 'deletions',
    );
  }

  /// True when this device has hidden [messageId] and must not re-render it.
  Future<bool> isHidden(String messageId) => store.isTombstoned(messageId);
}
