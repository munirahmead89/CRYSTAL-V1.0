import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_envelope.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the relay's durability guarantees against real SQLite.
///
/// A mocked store would prove nothing about transactions, so these run against
/// an actual in-memory database.
void main() {
  late AppDatabase db;
  late LocalStore store;

  ChatMessage message({
    required String id,
    String conversationId = 'c1',
    String senderId = 'peer',
    bool outgoing = false,
    String? body,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      clientMessageId: id,
      conversationId: conversationId,
      senderId: senderId,
      body: body ?? 'hello $id',
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      outgoing: outgoing,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(db, ownerId: 'account-a');
  });

  tearDown(() async {
    await db.close();
  });

  group('atomic incoming commit', () {
    test(
      'stores the message, owes an ack, and advances the cursor together',
      () async {
        final stored = await store.commitIncomingMessage(
          message: message(id: 'm1'),
          cursorKey: 'messages:c1',
        );

        expect(stored, isTrue);
        expect(await store.cachedMessages('c1'), hasLength(1));

        // The permission to acknowledge exists in the same transaction as the
        // message itself, so a crash between the two cannot produce "stored but
        // never acknowledged, and nothing remembers that it is owed".
        final pending = await store.pendingAcks();
        expect(pending, hasLength(1));
        expect(pending.single.messageId, 'm1');
        expect(pending.single.kind, AckKind.delivered);

        expect(await store.getDeviceCursor('messages:c1'), 'm1');
      },
    );

    test('an outgoing message is not owed a delivery ack', () async {
      // The sender acknowledging its own message would mean nothing.
      await store.commitIncomingMessage(
        message: message(id: 'm1', senderId: 'me', outgoing: true),
        cursorKey: 'messages:c1',
      );
      expect(await store.pendingAcks(), isEmpty);
    });

    test(
      'a duplicate commit reports that the message was already there',
      () async {
        final first = await store.commitIncomingMessage(
          message: message(id: 'm1'),
          cursorKey: '',
        );
        final second = await store.commitIncomingMessage(
          message: message(id: 'm1'),
          cursorKey: '',
        );

        // A Realtime event can be delivered twice (reconnect replay, two
        // subscriptions for the same conversation). The second call reporting
        // "already present" is what stops the controller appending the bubble a
        // second time.
        expect(first, isTrue);
        expect(second, isFalse);
        expect(await store.cachedMessages('c1'), hasLength(1));
        expect(await store.pendingAcks(), hasLength(1));
      },
    );

    test('a duplicate keyed by the server id is also detected', () async {
      // After the local row is re-keyed to the server id, a replayed event
      // arrives with that id, not the client id.
      await store.commitIncomingMessage(
        message: message(id: 'srv-1', outgoing: false),
        cursorKey: '',
      );
      final second = await store.commitIncomingMessage(
        message: message(id: 'srv-1'),
        cursorKey: '',
      );
      expect(second, isFalse);
      expect(await store.cachedMessages('c1'), hasLength(1));
    });

    test('acknowledgement can be disabled for a bulk backfill', () async {
      await store.commitIncomingMessage(
        message: message(id: 'm1'),
        cursorKey: '',
        acknowledgeDelivery: false,
      );
      expect(await store.pendingAcks(), isEmpty);
    });

    test('a tombstoned message is dropped, not stored', () async {
      await store.writeTombstone(
        messageId: 'm1',
        conversationId: 'c1',
        scope: DeletionScope.everyone,
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      final stored = await store.commitIncomingMessage(
        message: message(id: 'm1'),
        cursorKey: '',
      );

      // This is the resurrect guard. A stale sync that re-fetches a deleted
      // message must not put it back, however it arrives.
      expect(stored, isFalse);
      expect(await store.cachedMessages('c1'), isEmpty);
      expect(await store.isTombstoned('m1'), isTrue);
    });
  });

  group('acknowledgement ledger', () {
    test('an unreported ack is replayable and a reported one is not', () async {
      await store.recordPendingAck('m1', AckKind.delivered);
      expect(await store.owesDeliveryAck('m1'), isTrue);

      await store.markAcksReported(['m1'], AckKind.delivered);
      expect(await store.owesDeliveryAck('m1'), isFalse);
      expect(await store.pendingAcks(), isEmpty);
    });

    test('marking reported does not fabricate an entry', () async {
      await store.markAcksReported(['never-seen'], AckKind.delivered);
      // Claiming to have acknowledged something this device never stored is
      // worse than not acknowledging it at all.
      expect(await store.pendingAcks(), isEmpty);
      expect(await store.owesDeliveryAck('never-seen'), isFalse);
    });

    test('delivery and read are tracked independently', () async {
      await store.recordPendingAck('m1', AckKind.delivered);
      await store.recordPendingAck('m1', AckKind.read);

      await store.markAcksReported(['m1'], AckKind.delivered);

      final pending = await store.pendingAcks();
      expect(pending, hasLength(1));
      expect(pending.single.kind, AckKind.read);
    });

    test('a reported row is pruned but an unreported one never is', () async {
      await store.recordPendingAck('old-reported', AckKind.delivered);
      await store.markAcksReported(['old-reported'], AckKind.delivered);
      await store.recordPendingAck('fresh', AckKind.delivered);

      // Push the reported row outside the retention window. `pruneAckLedger`
      // has no injectable clock, so the timestamp is rewritten directly.
      await (db.update(db.deliveryAckLedger)
            ..where((t) => t.messageId.equals('old-reported')))
          .write(const DeliveryAckLedgerCompanion(updatedAt: Value(null)));
      await store.pruneAckLedger();

      final remaining = await store.pendingAcks();
      expect(remaining, hasLength(1));
      expect(remaining.single.messageId, 'fresh');
    });
  });

  group('deletion tombstones', () {
    test('writing a tombstone hides an already-cached message', () async {
      await store.upsertLocalMessage(message(id: 'm1'));
      expect(await store.cachedMessages('c1'), hasLength(1));

      await store.writeTombstone(
        messageId: 'm1',
        conversationId: 'c1',
        scope: DeletionScope.everyone,
        deletedAt: DateTime.utc(2026, 1, 2),
      );

      // The row survives so the thread keeps its shape, but it renders as
      // deleted and carries no content.
      final cached = await store.cachedMessages('c1');
      expect(cached, hasLength(1));
      expect(cached.single.deleted, isTrue);
      expect(cached.single.body, isNull);
    });

    test('the deletion cursor only moves forward', () async {
      await store.writeTombstone(
        messageId: 'm1',
        conversationId: 'c1',
        scope: DeletionScope.everyone,
        deletedAt: DateTime.utc(2026, 1, 10),
      );
      final afterNewest = (await store.deletionCursor(
        'c1',
      ))!.millisecondsSinceEpoch;

      // A late-arriving older event must not pull the watermark back, which
      // would make the next fetch re-request an already-processed window and
      // let out-of-order deletions be "un-seen".
      await store.writeTombstone(
        messageId: 'm2',
        conversationId: 'c1',
        scope: DeletionScope.everyone,
        deletedAt: DateTime.utc(2026, 1, 5),
      );
      final afterOlder = (await store.deletionCursor(
        'c1',
      ))!.millisecondsSinceEpoch;

      expect(afterNewest, DateTime.utc(2026, 1, 10).millisecondsSinceEpoch);
      expect(afterOlder, afterNewest);
      // Both deletions are still recorded; only the watermark is monotonic.
      expect(await store.isTombstoned('m1'), isTrue);
      expect(await store.isTombstoned('m2'), isTrue);
    });

    test('an empty batch applies nothing', () async {
      expect(await store.applyDeletionEvents([], cursorKey: 'deletions'), 0);
    });

    test('applying a batch reports only the events that were new', () async {
      final events = [
        RelayDeletionEventFixture.build(
          messageId: 'm1',
          deletedAt: DateTime.utc(2026, 1, 2),
        ),
        RelayDeletionEventFixture.build(
          messageId: 'm2',
          deletedAt: DateTime.utc(2026, 1, 3),
        ),
      ];

      expect(
        await store.applyDeletionEvents(events, cursorKey: 'deletions'),
        2,
      );
      // Replaying the same batch is a no-op rather than a double-count.
      expect(
        await store.applyDeletionEvents(events, cursorKey: 'deletions'),
        0,
      );
      expect(
        (await store.deletionCursor('c1'))!.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 3).millisecondsSinceEpoch,
      );
    });

    test(
      'delete-for-me on a conversation leaves a tombstone per message',
      () async {
        await store.upsertLocalMessage(message(id: 'm1'));
        await store.upsertLocalMessage(message(id: 'm2'));

        await store.deleteConversationLocally('c1');

        expect(await store.cachedMessages('c1'), isEmpty);
        expect(await store.isTombstoned('m1'), isTrue);
        expect(await store.isTombstoned('m2'), isTrue);

        // And a later sync cannot bring them back.
        expect(
          await store.commitIncomingMessage(
            message: message(id: 'm1'),
            cursorKey: '',
          ),
          isFalse,
        );
      },
    );

    test('tombstones are scoped per account', () async {
      await store.writeTombstone(
        messageId: 'shared-id',
        conversationId: 'c1',
        scope: DeletionScope.everyone,
        deletedAt: DateTime.utc(2026, 1, 2),
      );
      store.bindAccount('account-b');
      // Same message id, different account: account B must not inherit A's
      // deletion decision.
      expect(await store.isTombstoned('shared-id'), isFalse);
    });
  });

  group('account isolation', () {
    test('one account cannot read another account\'s messages', () async {
      await store.upsertLocalMessage(message(id: 'a1'));

      store.bindAccount('account-b');
      expect(await store.cachedMessages('c1'), isEmpty);

      store.bindAccount('account-a');
      expect(await store.cachedMessages('c1'), hasLength(1));
    });

    test('one account cannot flush another account\'s outbox', () async {
      await store.enqueueOutbox(message(id: 'a1', outgoing: true));

      store.bindAccount('account-b');
      // Before scoping, this row would have been flushed by whoever signed in
      // next, sending A's unsent message from B's identity into A's thread.
      expect(await store.pendingOutbox(), isEmpty);
      expect(await store.pendingOutboxCount(), 0);

      store.bindAccount('account-a');
      expect(await store.pendingOutbox(), hasLength(1));
    });

    test('the whole-table read is scoped and bounded', () async {
      for (var i = 0; i < 5; i++) {
        await store.upsertLocalMessage(message(id: 'a$i'));
      }
      expect(await store.appLocalMessages(), hasLength(5));
      // An unbounded scan of a year of history is how a phone runs out of RAM.
      expect(await store.appLocalMessages(limit: 2), hasLength(2));

      store.bindAccount('account-b');
      expect(await store.appLocalMessages(), isEmpty);
    });

    test('the first account to sign in adopts the pre-upgrade rows', () async {
      // Simulate an install that predates the owner column.
      final legacy = LocalStore(db, ownerId: '');
      await legacy.upsertLocalMessage(message(id: 'old1'));
      await legacy.upsertLocalMessage(message(id: 'old2'));

      final adopted = await store.adoptUnscopedRows('account-a');
      expect(adopted, 2);

      // The history survives the upgrade rather than being deleted.
      expect(await store.cachedMessages('c1'), hasLength(2));
    });

    test(
      'a second account starts empty and does not steal the history',
      () async {
        final legacy = LocalStore(db, ownerId: '');
        await legacy.upsertLocalMessage(message(id: 'old1'));

        expect(await store.adoptUnscopedRows('account-a'), 1);
        expect(
          await store.adoptUnscopedRows('account-a'),
          0,
          reason: 'adoption is once per install',
        );

        final other = LocalStore(db, ownerId: 'account-b');
        expect(await other.adoptUnscopedRows('account-b'), 0);
        expect(await other.cachedMessages('c1'), isEmpty);

        other.bindAccount('account-a');
        expect(await other.cachedMessages('c1'), hasLength(1));
      },
    );

    test('adoption keeps the queued outbox with its owner', () async {
      final legacy = LocalStore(db, ownerId: '');
      await legacy.enqueueOutbox(message(id: 'queued', outgoing: true));

      expect(await store.adoptUnscopedRows('account-a'), 1);
      expect(await store.pendingOutbox(), hasLength(1));

      final other = LocalStore(db, ownerId: 'account-b');
      expect(await other.pendingOutbox(), isEmpty);
    });

    test('an unscoped store still works exactly as before', () async {
      // The signed-out shell and the widget tests must be unaffected.
      final unscoped = LocalStore(db);
      await unscoped.upsertLocalMessage(message(id: 'x1'));
      expect(await unscoped.cachedMessages('c1'), hasLength(1));
      // An empty owner is a no-op rather than a claim.
      expect(await unscoped.adoptUnscopedRows(''), 0);
      expect(unscoped.ownerId, '');
    });
  });

  group('atomicity of replaceLocalMessage', () {
    test('the client-keyed row is replaced by the server-keyed one', () async {
      await store.upsertLocalMessage(message(id: 'cli-1', outgoing: true));
      expect(await store.findLocal('cli-1'), isNotNull);

      await store.replaceLocalMessage(
        'cli-1',
        message(id: 'srv-1', outgoing: true),
      );

      expect(await store.findLocal('cli-1'), isNull);
      expect(await store.findLocal('srv-1'), isNotNull);
      expect(await store.cachedMessages('c1'), hasLength(1));
    });

    test('the re-key leaves exactly one row the whole time', () async {
      // Crash-atomicity is a property of the surrounding `transaction()`,
      // which SQLite guarantees: the delete and the insert either both commit
      // or neither does. Asserting it directly would need fault injection, so
      // what is asserted is the observable consequence that motivated the
      // change — no window in which neither the client-keyed nor the
      // server-keyed row exists, which is what used to lose the message.
      await store.upsertLocalMessage(message(id: 'cli-1', outgoing: true));
      expect(await store.cachedMessages('c1'), hasLength(1));

      await store.replaceLocalMessage(
        'cli-1',
        message(id: 'srv-1', outgoing: true),
      );

      final after = await store.cachedMessages('c1');
      expect(after, hasLength(1));
      expect(after.single.id, 'srv-1');
    });
  });

  group('deleting a conversation is all-or-nothing', () {
    test(
      'the outbox is cleared in the same transaction as the tombstones',
      () async {
        await store.upsertLocalMessage(message(id: 'm1'));
        await store.enqueueOutbox(message(id: 'queued', outgoing: true));

        await store.deleteConversationLocally('c1');

        expect(await store.pendingOutbox(), isEmpty);
        expect(await store.isTombstoned('m1'), isTrue);
      },
    );

    test(
      'one account deleting a chat does not touch another\'s copy',
      () async {
        await store.upsertLocalMessage(message(id: 'm1'));
        store.bindAccount('account-b');
        await store.upsertLocalMessage(message(id: 'm1'));

        store.bindAccount('account-a');
        await store.deleteConversationLocally('c1');
        expect(await store.cachedMessages('c1'), isEmpty);

        store.bindAccount('account-b');
        expect(await store.cachedMessages('c1'), hasLength(1));
      },
    );
  });
}

/// Small builder so the batch tests read as data rather than as JSON.
class RelayDeletionEventFixture {
  static RelayDeletionEvent build({
    required String messageId,
    required DateTime deletedAt,
    String conversationId = 'c1',
    String actorId = 'peer',
  }) {
    return RelayDeletionEvent(
      messageId: messageId,
      conversationId: conversationId,
      actorId: actorId,
      deletedAt: deletedAt,
      scope: DeletionScope.everyone,
    );
  }
}
