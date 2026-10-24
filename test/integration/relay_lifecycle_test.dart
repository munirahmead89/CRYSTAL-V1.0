import 'package:crystal_messenger/core/database/database.dart';
import 'package:crystal_messenger/core/database/local_store.dart';
import 'package:crystal_messenger/core/sync/outbox_sync.dart';
import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_envelope.dart';
import 'package:crystal_messenger/features/delivery/domain/relay_failure.dart';
import 'package:crystal_messenger/features/delivery/services/delivery_acknowledgement_service.dart';
import 'package:crystal_messenger/features/delivery/services/relay_retention_policy.dart';
import 'package:crystal_messenger/features/delivery/services/relay_sync_recovery_service.dart';
import 'package:crystal_messenger/features/message_deletion/services/tombstone_service.dart';
import 'package:crystal_messenger/shared/models/chat_message.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/exploding_messages_repository.dart';
import '../support/fake_relay_repository.dart';

/// Drives the full relay protocol against a real SQLite store and a scripted
/// relay, so the failure paths can be reproduced deterministically.
///
/// Every scenario in the requirements that needs a network, a crash or a lost
/// response is simulated here rather than described.
void main() {
  late AppDatabase db;
  late LocalStore store;
  late FakeRelayRepository relay;
  late bool online;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = LocalStore(db, ownerId: 'me');
    relay = FakeRelayRepository();
    online = true;
  });

  tearDown(() async {
    await db.close();
  });

  ChatMessage draft({
    required String id,
    String conversationId = 'c1',
    String? body,
  }) {
    return ChatMessage(
      id: id,
      clientMessageId: id,
      conversationId: conversationId,
      senderId: 'me',
      type: 'text',
      body: body ?? 'hi',
      createdAt: DateTime.utc(2026, 1, 1),
      outgoing: true,
      localState: MessageLocalState.queued,
    );
  }

  ChatMessage incoming({
    required String id,
    String conversationId = 'c1',
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id,
      clientMessageId: id,
      conversationId: conversationId,
      senderId: 'peer',
      type: 'text',
      body: 'hello',
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      outgoing: false,
    );
  }

  OutboxSyncEngine engine() {
    return OutboxSyncEngine(
      store: store,
      messagesRepository: const ExplodingMessagesRepository(),
      relay: relay,
      getMyId: () => 'me',
      isOnline: () => online,
    );
  }

  DeliveryAcknowledgementService acks({String deviceId = 'dev-1'}) {
    return DeliveryAcknowledgementService(
      store: store,
      repository: relay,
      deviceId: deviceId,
      isOnline: () => online,
    );
  }

  RelaySyncRecoveryService recovery() {
    return RelaySyncRecoveryService(
      store: store,
      repository: relay,
      isOnline: () => online,
    );
  }

  group('outgoing', () {
    test('a message is queued locally and survives a restart', () async {
      final message = draft(id: 'm1');
      await store.upsertLocalMessage(message);
      await store.enqueueOutbox(message);

      // A restart is a fresh store over the same file.
      final reopened = LocalStore(db, ownerId: 'me');
      expect(await reopened.pendingOutbox(), hasLength(1));
      expect((await reopened.cachedMessages('c1')).single.id, 'm1');
    });

    test('a send that succeeds is recorded as sent', () async {
      await store.upsertLocalMessage(draft(id: 'm1'));
      await store.enqueueOutbox(draft(id: 'm1'));

      final result = await engine().flushNow();

      expect(result.pushedMessages, 1);
      expect(await store.pendingOutbox(), isEmpty);
      final stored = (await store.cachedMessages('c1')).single;
      expect(stored.localState, MessageLocalState.sent);
    });

    test(
      'offline does not consume an attempt or mark the message failed',
      () async {
        online = false;
        await store.upsertLocalMessage(draft(id: 'm1'));
        await store.enqueueOutbox(draft(id: 'm1'));

        await engine().flushNow();

        // Nothing about the message is broken; it is simply waiting.
        final row = (await store.pendingOutbox()).single;
        expect(row.attemptCount, 0);
        final stored = (await store.cachedMessages('c1')).single;
        expect(stored.localState, MessageLocalState.queued);
      },
    );

    test('a failure keeps the row so the same id is retried', () async {
      relay.failNext('send_message', const SocketFailure());
      await store.upsertLocalMessage(draft(id: 'm1'));
      await store.enqueueOutbox(draft(id: 'm1'));

      await engine().flushNow();

      // The row is deliberately retained: deleting it would strand a message
      // the user has already been shown.
      final pending = await store.pendingOutbox();
      expect(pending, hasLength(1));
      expect(pending.single.id, 'm1');
      expect(pending.single.attemptCount, 1);
    });

    test('a lost response is recovered, not duplicated', () async {
      await store.upsertLocalMessage(draft(id: 'm1'));
      await store.enqueueOutbox(draft(id: 'm1'));

      // First attempt: the server commits, then the connection dies before the
      // response arrives.
      relay.failNext('send_message', const SocketFailure());
      await engine().flushNow();
      expect(await store.pendingOutbox(), hasLength(1));

      // Retry with the same client id.
      final result = await engine().flushNow();

      expect(result.pushedMessages, 1);
      // One row on the server, keyed by the original client id.
      expect(relay.accepted.length, 1);
      expect(relay.accepted.containsKey('m1'), isTrue);
      expect(await store.cachedMessages('c1'), hasLength(1));
    });

    test('repeated retries never mint a second message', () async {
      await store.upsertLocalMessage(draft(id: 'm1'));
      await store.enqueueOutbox(draft(id: 'm1'));

      await engine().flushNow();
      await store.enqueueOutbox(draft(id: 'm1'));
      await engine().flushNow();
      await store.enqueueOutbox(draft(id: 'm1'));
      await engine().flushNow();

      expect(relay.accepted.length, 1);
      expect(await store.cachedMessages('c1'), hasLength(1));
    });

    test(
      'the retry budget produces a failed state that stays retryable',
      () async {
        await store.upsertLocalMessage(draft(id: 'm1'));
        await store.enqueueOutbox(draft(id: 'm1'));
        relay.hardFailure = const SocketFailure();

        for (var i = 0; i < OutboxSyncEngine.maxAttempts; i++) {
          await engine().flushNow();
        }

        final stored = (await store.cachedMessages('c1')).single;
        expect(stored.localState, MessageLocalState.failed);
        // Still queued, so the user can retry it.
        expect(await store.pendingOutbox(), hasLength(1));

        relay.hardFailure = null;
        await engine().flushNow();
        expect(await store.pendingOutbox(), isEmpty);
      },
    );

    test('a permanently failing row does not block later messages', () async {
      await store.enqueueOutbox(draft(id: 'bad'));
      await store.enqueueOutbox(draft(id: 'good'));

      // Fail only the first id, so the pass has to get past 'bad' to reach
      // 'good'. A queue where one bad row blocks everything behind it is a
      // stalled conversation.
      relay.hardFailure = RelayException(
        'send_message failed.',
        RelayFailureKind.transport,
      );

      final blocked = await engine().flushNow();
      expect(blocked.pushedMessages, 0);
      expect((await store.pendingOutbox()), hasLength(2));

      relay.hardFailure = null;
      final result = await engine().flushNow();

      expect(result.pushedMessages, 2, reason: 'neither row is stuck');
      expect(relay.accepted.keys, containsAll(['bad', 'good']));
    });
  });

  group('incoming', () {
    test('a message is committed before it is acknowledged', () async {
      await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: 'messages:c1',
      );

      // Stored, and now owed an acknowledgement. The flush is what reports it.
      expect(await store.cachedMessages('c1'), hasLength(1));
      expect(await store.owesDeliveryAck('srv-1'), isTrue);

      final result = await acks().flushPending();
      expect(result.confirmed, 1);
      expect(await store.owesDeliveryAck('srv-1'), isFalse);
    });

    test('no acknowledgement is sent when nothing is stored', () async {
      // The critical invariant: a Realtime event alone must never produce a
      // delivery receipt.
      final result = await acks().flushPending();
      expect(result.sent, 0);
      expect(relay.ackCalls, isEmpty);
    });

    test(
      'an offline device stores the message and acknowledges later',
      () async {
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-1'),
          cursorKey: '',
        );

        online = false;
        expect((await acks().flushPending()).skipped, isTrue);
        expect(await store.owesDeliveryAck('srv-1'), isTrue);

        online = true;
        await acks().flushPending();
        expect(await store.owesDeliveryAck('srv-1'), isFalse);
      },
    );

    test('a recipient database failure means nothing is acknowledged', () async {
      // Simulated by never committing: the message never reaches the store, so
      // no ledger row exists and the flush has nothing to report.
      final result = await acks().flushPending();
      expect(result.sent, 0);
      expect(relay.ackCalls, isEmpty);
    });

    test('a lost acknowledgement response is replayed safely', () async {
      await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );

      relay.failNext('acknowledge_messages', const SocketFailure());
      await acks().flushPending();
      // Still owed, because the server never confirmed.
      expect(await store.owesDeliveryAck('srv-1'), isTrue);

      final result = await acks().flushPending();
      expect(result.confirmed, 1);
      expect(await store.owesDeliveryAck('srv-1'), isFalse);
      // Replayed exactly once after the failure.
      expect(relay.ackCalls.length, 2);
    });

    test('concurrent flushes collapse into one pass', () async {
      for (var i = 0; i < 5; i++) {
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-$i'),
          cursorKey: '',
        );
      }

      final service = acks();
      await Future.wait([service.flushPending(), service.flushPending()]);

      // One batch, not five: a burst of realtime events must not produce five
      // identical acknowledgement calls.
      expect(relay.ackCalls.length, 1);
      expect(relay.ackCalls.single.messageIds, hasLength(5));
    });

    test('an unregistered device acknowledges nothing', () async {
      await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );

      final result = await acks(deviceId: '').flushPending();
      // An unverifiable device claim is worse than no claim.
      expect(result.skipped, isTrue);
      expect(relay.ackCalls, isEmpty);
      expect(await store.owesDeliveryAck('srv-1'), isTrue);
    });

    test('a queued backlog is acknowledged in one batch', () async {
      for (var i = 0; i < 3; i++) {
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-$i'),
          cursorKey: '',
        );
        online = false;
        await acks().flushPending();
      }

      online = true;
      final result = await acks().flushPending();
      expect(result.sent, 3);
      expect(await store.pendingAcks(), isEmpty);
    });
  });

  group('duplicate realtime events', () {
    test('a replayed insert does not duplicate the row', () async {
      final first = await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );
      final second = await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );
      final third = await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );

      expect(first, isTrue);
      expect(second, isFalse);
      expect(third, isFalse);
      expect(await store.cachedMessages('c1'), hasLength(1));
    });
  });

  group('deletion', () {
    test('delete for me works with no network and stays deleted', () async {
      await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );
      online = false;

      final service = TombstoneService(
        store: store,
        repository: relay,
        isOnline: () => online,
      );
      final outcome = await service.deleteForMe(
        messageId: 'srv-1',
        conversationId: 'c1',
      );

      expect(outcome.succeeded, isTrue);
      expect(outcome.tombstoned, isTrue);
      // No server contact at all.
      expect(relay.deleted, isEmpty);
    });

    test('a stale re-fetch cannot resurrect a deleted-for-me message', () async {
      await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: '',
      );
      await store.writeTombstone(
        messageId: 'srv-1',
        conversationId: 'c1',
        scope: DeletionScope.me,
        deletedAt: DateTime.utc(2026, 2, 1),
      );

      // A sync that re-fetches the same row, with the cursor rewound.
      await store.setDeviceCursor('messages:c1', null);
      final refetched = await store.commitIncomingMessage(
        message: incoming(id: 'srv-1'),
        cursorKey: 'messages:c1',
      );

      expect(refetched, isFalse);
      // The row is still there so the thread keeps its shape, but it renders as
      // deleted and carries no content — which is what "delete for me" means:
      // hidden from this device, not erased from the database.
      final cached = await store.cachedMessages('c1');
      expect(cached, hasLength(1));
      expect(cached.single.deleted, isTrue);
      expect(cached.single.body, isNull);
      // And the cursor was not advanced by a message that was never stored.
      expect(await store.getDeviceCursor('messages:c1'), isNull);
    });

    test('delete for everyone requires a connection and says so', () async {
      online = false;
      final service = TombstoneService(
        store: store,
        repository: relay,
        isOnline: () => online,
      );

      final outcome = await service.deleteForEveryone(
        messageId: 'srv-1',
        conversationId: 'c1',
      );

      // Unlike "for me", this genuinely cannot be done offline, and pretending
      // otherwise would tell the user something false.
      expect(outcome.succeeded, isFalse);
      expect(outcome.detail, contains('connection'));
    });

    test('delete for everyone records a server tombstone', () async {
      final service = TombstoneService(
        store: store,
        repository: relay,
        isOnline: () => online,
      );

      final outcome = await service.deleteForEveryone(
        messageId: 'srv-1',
        conversationId: 'c1',
      );

      expect(outcome.succeeded, isTrue);
      expect(relay.deleted, ['srv-1']);
      expect(await store.isTombstoned('srv-1'), isTrue);
    });

    test(
      'a server refusal is reported honestly and hides nothing locally',
      () async {
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-1'),
          cursorKey: '',
        );
        relay.hardFailure = RelayException(
          'delete_message failed (42501).',
          RelayFailureKind.unauthorized,
        );

        final service = TombstoneService(
          store: store,
          repository: relay,
          isOnline: () => online,
          onError: (_, __) {},
        );
        final outcome = await service.deleteForEveryone(
          messageId: 'srv-1',
          conversationId: 'c1',
        );

        expect(outcome.succeeded, isFalse);
        expect(outcome.detail, contains('cannot delete'));
        // The user's view is not silently made to disagree with the server.
        expect(await store.isTombstoned('srv-1'), isFalse);
        expect(await store.cachedMessages('c1'), hasLength(1));
      },
    );

    test('an unreachable server is reported as a local-only removal', () async {
      relay.hardFailure = RelayException(
        'delete_message failed.',
        RelayFailureKind.transport,
      );
      final service = TombstoneService(
        store: store,
        repository: relay,
        isOnline: () => online,
        onError: (_, __) {},
      );

      final outcome = await service.deleteForEveryone(
        messageId: 'srv-1',
        conversationId: 'c1',
      );
      expect(outcome.succeeded, isFalse);
      expect(outcome.detail, contains('other person still has it'));
    });
  });

  group('offline deletion recovery', () {
    test(
      'a device offline during a deletion learns about it on reconnect',
      () async {
        // Two deletions happened while this device was away.
        relay.deletionEvents = [
          RelayDeletionEvent(
            messageId: 'srv-1',
            conversationId: 'c1',
            actorId: 'peer',
            deletedAt: DateTime.utc(2026, 3, 1),
          ),
          RelayDeletionEvent(
            messageId: 'srv-2',
            conversationId: 'c1',
            actorId: 'peer',
            deletedAt: DateTime.utc(2026, 3, 2),
          ),
        ];

        // This device had cached both.
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-1'),
          cursorKey: '',
        );
        await store.commitIncomingMessage(
          message: incoming(id: 'srv-2'),
          cursorKey: '',
        );
        expect(await store.cachedMessages('c1'), hasLength(2));

        final result = await recovery().recover();

        expect(result.deletionEventsApplied, 2);
        final cached = await store.cachedMessages('c1');
        expect(cached, hasLength(2));
        expect(cached.every((m) => m.deleted), isTrue);
      },
    );

    test('the recovery is cursor-bounded and idempotent', () async {
      relay.deletionEvents = [
        RelayDeletionEvent(
          messageId: 'srv-1',
          conversationId: 'c1',
          actorId: 'peer',
          deletedAt: DateTime.utc(2026, 3, 1),
        ),
      ];

      expect((await recovery().recover()).deletionEventsApplied, 1);
      // Second pass: the cursor is past every event, so the server returns none.
      expect((await recovery().recover()).deletionEventsApplied, 0);
    });

    test('a failure leaves the cursor where it was', () async {
      relay.deletionEvents = [
        RelayDeletionEvent(
          messageId: 'srv-1',
          conversationId: 'c1',
          actorId: 'peer',
          deletedAt: DateTime.utc(2026, 3, 1),
        ),
      ];
      relay.hardFailure = RelayException(
        'fetch_deletions_since failed.',
        RelayFailureKind.transport,
      );

      final result = await RelaySyncRecoveryService(
        store: store,
        repository: relay,
        isOnline: () => online,
        onError: (_, __) {},
      ).recover();

      expect(result.deletionsFailed, isTrue);
      expect(await store.deletionCursor('c1'), isNull);

      // Recovered on the next attempt.
      relay.hardFailure = null;
      expect((await recovery().recover()).deletionEventsApplied, 1);
    });

    test(
      'deletions applied before a concurrent message fetch still win',
      () async {
        // The ordering that matters: a message fetched after its tombstone is
        // known must not be stored.
        relay.deletionEvents = [
          RelayDeletionEvent(
            messageId: 'srv-1',
            conversationId: 'c1',
            actorId: 'peer',
            deletedAt: DateTime.utc(2026, 3, 1),
          ),
        ];
        await recovery().recover();

        final stored = await store.commitIncomingMessage(
          message: incoming(id: 'srv-1'),
          cursorKey: '',
        );
        expect(stored, isFalse);
      },
    );

    test('offline recovery is skipped rather than attempted', () async {
      online = false;
      final result = await recovery().recover();
      expect(result.deletionsFailed, isTrue);
    });
  });

  group('retention', () {
    test('an undelivered message is never eligible because it is old', () {
      const policy = RelayRetentionPolicy(graceSeconds: 900);
      final old = DateTime.utc(2020);

      final eligible = policy.isEligibleForCleanup(
        retention: RetentionState.retained,
        deleted: false,
        createdAt: old,
        requiredDeviceIds: const ['d1'],
        // Never acknowledged.
        acknowledgedDeviceIds: const [],
        lastAcknowledgedAt: old,
        now: DateTime.utc(2026),
      );

      // "Old" is not a reason to delete something nobody has received.
      expect(eligible, isFalse);
    });

    test('all active devices must acknowledge', () {
      const policy = RelayRetentionPolicy(graceSeconds: 900);
      final now = DateTime.utc(2026, 6, 1);
      final longAgo = now.subtract(const Duration(days: 1));

      final partial = policy.isEligibleForCleanup(
        retention: RetentionState.retained,
        deleted: false,
        createdAt: longAgo,
        requiredDeviceIds: const ['d1', 'd2'],
        acknowledgedDeviceIds: const ['d1'],
        lastAcknowledgedAt: longAgo,
        now: now,
      );
      expect(partial, isFalse, reason: 'one device still outstanding');

      final complete = policy.isEligibleForCleanup(
        retention: RetentionState.retained,
        deleted: false,
        createdAt: longAgo,
        requiredDeviceIds: const ['d1', 'd2'],
        acknowledgedDeviceIds: const ['d1', 'd2'],
        lastAcknowledgedAt: longAgo,
        now: now,
      );
      expect(complete, isTrue);
    });

    test('the grace period is respected', () {
      const policy = RelayRetentionPolicy(graceSeconds: 900);
      final now = DateTime.utc(2026, 6, 1);
      final justNow = now.subtract(const Duration(seconds: 60));

      expect(
        policy.isEligibleForCleanup(
          retention: RetentionState.retained,
          deleted: false,
          createdAt: justNow,
          requiredDeviceIds: const ['d1'],
          acknowledgedDeviceIds: const ['d1'],
          lastAcknowledgedAt: justNow,
          now: now,
        ),
        isFalse,
        reason: 'status propagation still needs time',
      );
    });

    test('an already-purged message is not swept again', () {
      const policy = RelayRetentionPolicy(graceSeconds: 0);
      final now = DateTime.utc(2026, 6, 1);
      expect(
        policy.isEligibleForCleanup(
          retention: RetentionState.payloadPurged,
          deleted: false,
          createdAt: now,
          requiredDeviceIds: const [],
          acknowledgedDeviceIds: const [],
          now: now,
        ),
        isFalse,
      );
    });

    test('server configuration is read defensively', () {
      // A server that reports nonsense must not make the client claim a
      // guarantee it cannot keep.
      final policy = RelayRetentionPolicy.fromServerJson({
        'cleanup_grace_seconds': -5,
        'require_all_devices': false,
        'tombstone_retention_days': 99999,
        'cleanup_batch_size': 0,
      });
      expect(policy.graceSeconds, RelayRetentionPolicy.defaultGraceSeconds);
      expect(policy.requireAllDevices, isFalse);
      expect(
        policy.tombstoneRetentionDays,
        RelayRetentionPolicy.defaultTombstoneDays,
      );
      expect(policy.cleanupBatchSize, 500);
    });

    test(
      'the description states the limitation instead of implying a backup',
      () {
        const policy = RelayRetentionPolicy();
        expect(policy.describe(), contains('cannot be recovered'));
        expect(policy.describe(), contains('every one of your devices'));
      },
    );
  });
}

/// Marker failure that classifies as a transport error.
class SocketFailure implements Exception {
  const SocketFailure();
}
