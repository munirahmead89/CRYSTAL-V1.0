import 'package:crystal_messenger/features/delivery/domain/relay_envelope.dart';
import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_relay_repository.dart';

void main() {
  group('RelayEnvelope.tryParse', () {
    test('decodes a complete server row', () {
      final envelope = RelayEnvelope.tryParse(
        relayRow(
          id: 'srv-1',
          clientMessageId: 'cli-1',
          conversationId: 'c1',
          senderId: 'u1',
          recipientId: 'u2',
          text: 'hello',
          createdAt: DateTime.utc(2026, 3, 1, 12),
        ),
      );

      expect(envelope, isNotNull);
      expect(envelope!.id, 'srv-1');
      expect(envelope.clientMessageId, 'cli-1');
      expect(envelope.recipientId, 'u2');
      expect(envelope.payload, 'hello');
      expect(envelope.serverCreatedAt, DateTime.utc(2026, 3, 1, 12));
      expect(envelope.isDeleted, isFalse);
      expect(envelope.schemaVersion, RelaySchemaVersion.v1);
    });

    test('rejects a row missing a required column', () {
      // A row with no conversation id cannot be authorised or filed, so it must
      // be dropped rather than stored with a blank key.
      expect(
        RelayEnvelope.tryParse({'id': 'srv-1', 'sender_id': 'u1'}),
        isNull,
      );
      expect(
        RelayEnvelope.tryParse({'conversation_id': 'c1', 'sender_id': 'u1'}),
        isNull,
      );
      expect(RelayEnvelope.tryParse(const {}), isNull);
      expect(
        RelayEnvelope.tryParse({
          'id': '',
          'conversation_id': 'c1',
          'sender_id': 'u',
        }),
        isNull,
      );
    });

    test('falls back to the row id when client_message_id is absent', () {
      // A database built from 00030 has no client_message_id column at all.
      final envelope = RelayEnvelope.tryParse({
        'id': 'srv-9',
        'conversation_id': 'c1',
        'sender_id': 'u1',
      });
      expect(envelope!.clientMessageId, 'srv-9');
    });

    test('reads both the legacy and the current reply column', () {
      // 00030 named it reply_to_id; the client writes reply_to_message_id.
      final legacy = RelayEnvelope.tryParse({
        ...relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        'reply_to_id': 'parent-1',
        'reply_to_message_id': null,
      });
      final current = RelayEnvelope.tryParse(
        relayRow(
          id: 'b',
          conversationId: 'c',
          senderId: 'u',
          replyToMessageId: 'parent-2',
        ),
      );
      expect(legacy!.replyToMessageId, 'parent-1');
      expect(current!.replyToMessageId, 'parent-2');
    });

    test('reads the legacy content column as the payload', () {
      final envelope = RelayEnvelope.tryParse({
        ...relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        'text': null,
        'content': 'legacy body',
      });
      expect(envelope!.payload, 'legacy body');
    });

    test('an unknown message type degrades to text', () {
      final envelope = RelayEnvelope.tryParse(
        relayRow(id: 'a', conversationId: 'c', senderId: 'u', type: 'sticker'),
      );
      expect(envelope!.type, RelayMessageType.text);
    });

    test('decodes bytea ciphertext from the hex form', () {
      final envelope = RelayEnvelope.tryParse({
        ...relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        'ciphertext': r'\x00ff10',
        'encryption_version': 1,
      });
      expect(envelope!.ciphertext, [0, 255, 16]);
      expect(envelope.encryptionVersion, EncryptionVersion.reserved);
      expect(envelope.encryptionVersion.isEncrypted, isTrue);
    });

    test('odd-length or non-hex ciphertext is dropped, not thrown on', () {
      // A truncated bytea from a partially-written row must not become a cast
      // failure in the middle of a chat sync.
      final odd = RelayEnvelope.tryParse({
        ...relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        'ciphertext': r'\x0',
      });
      expect(odd, isNotNull);
      expect(odd!.ciphertext, isNull);

      final notHex = RelayEnvelope.tryParse({
        ...relayRow(id: 'b', conversationId: 'c', senderId: 'u'),
        'ciphertext': r'\xzzzz',
      });
      expect(notHex, isNotNull);
      expect(notHex!.ciphertext, isNull);
    });

    test('a two-digit bytea value decodes to one byte', () {
      final envelope = RelayEnvelope.tryParse({
        ...relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        'ciphertext': r'\x0f',
      });
      expect(envelope!.ciphertext, [15]);
    });

    test('a deleted message is renderable with a null payload', () {
      // Delete-for-everyone nulls the body and sets deleted_at in one update.
      // That combination is normal, not an error.
      final envelope = RelayEnvelope.tryParse(
        relayRow(
          id: 'a',
          conversationId: 'c',
          senderId: 'u',
          deletedAt: DateTime.utc(2026, 4, 1),
          retention: 'payload_purged',
        ),
      );
      expect(envelope!.isDeleted, isTrue);
      expect(envelope.payload, isNull);
      expect(envelope.retention, RetentionState.payloadPurged);
      expect(envelope.payloadIsPurged, isTrue);
      expect(envelope.derivedState, DeliveryState.deleted);
    });

    test('state is derived from receipts, not a mutable status column', () {
      RelayEnvelope withReceipts({DateTime? deliveredAt, DateTime? readAt}) =>
          RelayEnvelope.tryParse(
            relayRow(
              id: 'a',
              conversationId: 'c',
              senderId: 'u',
              deliveredAt: deliveredAt,
              readAt: readAt,
            ),
          )!;

      expect(withReceipts().derivedState, DeliveryState.sent);
      expect(
        withReceipts(deliveredAt: DateTime.utc(2026, 1, 2)).derivedState,
        DeliveryState.delivered,
      );
      expect(
        withReceipts(
          deliveredAt: DateTime.utc(2026, 1, 2),
          readAt: DateTime.utc(2026, 1, 3),
        ).derivedState,
        DeliveryState.read,
      );
    });

    test('read outranks delivered when both are present', () {
      final envelope = RelayEnvelope.tryParse(
        relayRow(
          id: 'a',
          conversationId: 'c',
          senderId: 'u',
          deliveredAt: DateTime.utc(2026, 1, 5),
          readAt: DateTime.utc(2026, 1, 4),
        ),
      );
      // A clock skew between devices must not make a read message look merely
      // delivered.
      expect(envelope!.derivedState, DeliveryState.read);
    });
  });

  group('RelayEnvelope.parsePage', () {
    test('keeps the readable rows and counts the unreadable ones', () {
      final page = RelayEnvelope.parsePage([
        relayRow(id: 'a', conversationId: 'c', senderId: 'u'),
        {'garbage': true},
        'not a map',
        relayRow(id: 'b', conversationId: 'c', senderId: 'u'),
      ]);
      expect(page.length, 2);
      expect(page.rejected, 2);
    });

    test('a non-list payload yields an empty page rather than throwing', () {
      final page = RelayEnvelope.parsePage(null);
      expect(page.isEmpty, isTrue);
      expect(page.rejected, 0);
      expect(RelayEnvelope.parsePage('nope').length, 0);
    });
  });

  group('RelayDeletionEvent', () {
    test('decodes a complete event', () {
      final event = RelayDeletionEvent.tryParse({
        'message_id': 'm1',
        'conversation_id': 'c1',
        'actor_id': 'u1',
        'scope': 'everyone',
        'deleted_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        'payload_version': 2,
      });
      expect(event, isNotNull);
      expect(event!.messageId, 'm1');
      expect(event.scope, DeletionScope.everyone);
      expect(event.payloadVersion, 2);
    });

    test('rejects an event with no id or no timestamp', () {
      // Both are load-bearing: without an id nothing can be hidden, and without
      // a timestamp the deletion cursor cannot advance past it.
      expect(RelayDeletionEvent.tryParse({'conversation_id': 'c'}), isNull);
      expect(
        RelayDeletionEvent.tryParse({
          'message_id': 'm',
          'conversation_id': 'c',
        }),
        isNull,
      );
      expect(
        RelayDeletionEvent.tryParse({'message_id': 'm', 'deleted_at': 'x'}),
        isNull,
      );
    });

    test('parseList skips junk and keeps the rest', () {
      final events = RelayDeletionEvent.parseList([
        {
          'message_id': 'm1',
          'conversation_id': 'c1',
          'deleted_at': DateTime.utc(2026, 5, 1).toIso8601String(),
        },
        'nope',
        {'missing': 'everything'},
      ]);
      expect(events.length, 1);
      expect(events.single.messageId, 'm1');
    });
  });

  group('RelaySendRequest', () {
    test('encodes ciphertext as the Postgres bytea hex form', () {
      final params = RelaySendRequest(
        conversationId: 'c1',
        clientMessageId: 'cli-1',
        payload: 'hi',
        ciphertext: [0x00, 0xab],
      ).toRpcParams();

      expect(params['p_conversation_id'], 'c1');
      expect(params['p_client_message_id'], 'cli-1');
      expect(params['p_message_type'], 'text');
      expect(params['p_text'], 'hi');
      expect(params['p_ciphertext'], r'\x00ab');
      expect(params['p_schema_version'], RelaySchemaVersion.current.value);
    });

    test('omits optional parameters entirely when absent', () {
      final params = RelaySendRequest(
        conversationId: 'c1',
        clientMessageId: 'cli-1',
      ).toRpcParams();
      expect(params.containsKey('p_text'), isFalse);
      expect(params.containsKey('p_media'), isFalse);
      expect(params.containsKey('p_ciphertext'), isFalse);
      expect(params.containsKey('p_reply_to_message_id'), isFalse);
    });

    test('never puts a plaintext encryption_version next to plaintext', () {
      final plaintext = RelaySendRequest(
        conversationId: 'c',
        clientMessageId: 'cli',
        payload: 'visible',
      ).toRpcParams();
      expect(plaintext.containsKey('p_encryption_version'), isFalse);

      final encrypted = RelaySendRequest(
        conversationId: 'c',
        clientMessageId: 'cli',
        ciphertext: [1, 2],
        encryptionVersion: EncryptionVersion.reserved,
      ).toRpcParams();
      expect(encrypted.containsKey('p_text'), isFalse);
      expect(encrypted['p_encryption_version'], 1);
    });
  });

  group('result parsing', () {
    test('RelayAckResult defaults to zero rather than throwing', () {
      final result = RelayAckResult.parse(null);
      expect(result.accepted, 0);
      expect(result.rejected, 0);
    });

    test('RelayAckResult reads the server counters', () {
      final result = RelayAckResult.parse({
        'accepted': 3,
        'rejected': 1,
        'device_id': 'dev-1',
      });
      expect(result.accepted, 3);
      expect(result.rejected, 1);
      expect(result.deviceId, 'dev-1');
    });

    test('RelayReadResult exposes the suppressed count', () {
      final result = RelayReadResult.parse({'marked': 0, 'suppressed': 4});
      expect(result.marked, 0);
    });

    test('SendOutcome maps the duplicate flag', () {
      expect(SendOutcome.fromDuplicate(false), SendOutcome.stored);
      expect(SendOutcome.fromDuplicate(true), SendOutcome.recovered);
    });
  });

  group('AckLedgerEntry', () {
    test('round-trips through JSON', () {
      final entry = AckLedgerEntry(
        messageId: 'm1',
        kind: AckKind.delivered,
        reported: true,
        reportedAt: DateTime.utc(2026, 6, 1),
        attempts: 2,
      );
      final decoded = AckLedgerEntry.tryParse(
        Map<String, dynamic>.from(entry.toJson()),
      );
      expect(decoded!.messageId, 'm1');
      expect(decoded.kind, AckKind.delivered);
      expect(decoded.reported, isTrue);
      expect(decoded.attempts, 2);
    });

    test('an entry with no message id is rejected', () {
      expect(AckLedgerEntry.tryParse({'kind': 'read'}), isNull);
    });
  });
}
