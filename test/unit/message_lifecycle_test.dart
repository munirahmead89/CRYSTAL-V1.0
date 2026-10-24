import 'package:crystal_messenger/features/delivery/domain/message_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryState', () {
    test('parses every known wire value', () {
      for (final state in DeliveryState.values) {
        expect(DeliveryState.fromString(state.name), state);
      }
    });

    test('an unknown value falls back instead of throwing', () {
      // A row written by a newer build, or a corrupted column value, must
      // render as something rather than take the chat screen down.
      expect(DeliveryState.fromString('quantum'), DeliveryState.sent);
      expect(DeliveryState.fromString(null), DeliveryState.sent);
      expect(DeliveryState.fromString(''), DeliveryState.sent);
    });

    test('a caller-supplied fallback wins over the default', () {
      expect(
        DeliveryState.fromString('quantum', fallback: DeliveryState.deleted),
        DeliveryState.deleted,
      );
      expect(
        DeliveryState.fromString(null, fallback: DeliveryState.pending),
        DeliveryState.pending,
      );
    });

    test('only deleted is terminal for the send path', () {
      expect(DeliveryState.deleted.isTerminal, isTrue);
      expect(DeliveryState.failed.isTerminal, isFalse);
    });

    test('pending and failed are the states that still await an upload', () {
      expect(DeliveryState.pending.awaitsUpload, isTrue);
      expect(DeliveryState.failed.awaitsUpload, isTrue);
      // `sent` means the server accepted it. Re-sending would be a duplicate.
      expect(DeliveryState.sent.awaitsUpload, isFalse);
      expect(DeliveryState.delivered.awaitsUpload, isFalse);
      expect(DeliveryState.read.awaitsUpload, isFalse);
    });
  });

  group('AckKind', () {
    test('delivery and read are distinct values', () {
      // The whole point: a collapsed pair is what makes "marked read on
      // arrival" possible.
      expect(AckKind.delivered, isNot(AckKind.read));
      expect(AckKind.values.length, 2);
    });

    test('parses both wire values and defaults safely', () {
      expect(AckKind.fromString('delivered'), AckKind.delivered);
      expect(AckKind.fromString('read'), AckKind.read);
      // Delivery is the weaker claim, so it is the safe default.
      expect(AckKind.fromString('nonsense'), AckKind.delivered);
      expect(AckKind.fromString(null), AckKind.delivered);
    });
  });

  group('RetentionState', () {
    test('round-trips through the Postgres spelling', () {
      for (final state in RetentionState.values) {
        expect(RetentionState.fromString(state.wireValue), state);
      }
      // The 00030 schema stored it camelCase; both must still decode.
      expect(
        RetentionState.fromString('payloadPurged'),
        RetentionState.payloadPurged,
      );
    });

    test('an unknown value is treated as retained, not as purged', () {
      // Defaulting to purged would make the client hide live content.
      expect(RetentionState.fromString('???'), RetentionState.retained);
      expect(RetentionState.fromString(null), RetentionState.retained);
    });
  });

  group('DeletionScope', () {
    test('me and everyone are separate scopes', () {
      expect(DeletionScope.fromString('me'), DeletionScope.me);
      expect(DeletionScope.fromString('everyone'), DeletionScope.everyone);
      expect(DeletionScope.values.length, 2);
    });
  });

  group('RelayMessageType', () {
    test('accepts exactly the server allowlist', () {
      for (final wire in [
        'text',
        'image',
        'file',
        'voice',
        'video',
        'system',
      ]) {
        expect(RelayMessageType.tryParse(wire), isNotNull);
      }
    });

    test('rejects a type the server would refuse', () {
      expect(RelayMessageType.tryParse('exec'), isNull);
      expect(RelayMessageType.tryParse(''), isNull);
    });

    test('an unknown type degrades to text rather than hiding the message', () {
      // A newer server must not be able to make a message invisible to an
      // older client by introducing a type it does not know.
      expect(RelayMessageType.tryParse('sticker'), isNull);
      expect(RelayMessageType.parse('sticker'), RelayMessageType.text);
      expect(RelayMessageType.parse(null), RelayMessageType.text);
    });
  });

  group('RelaySchemaVersion', () {
    test('clamps an unknown version to the newest known', () {
      expect(RelaySchemaVersion.fromInt(1), RelaySchemaVersion.v1);
      expect(RelaySchemaVersion.fromInt(2), RelaySchemaVersion.v2);
      expect(RelaySchemaVersion.fromInt(99), RelaySchemaVersion.current);
      expect(RelaySchemaVersion.fromInt(null), RelaySchemaVersion.current);
    });
  });

  group('EncryptionVersion', () {
    test('none is the honest default and is not encrypted', () {
      // There is no E2EE in this build. The field must not imply otherwise.
      expect(EncryptionVersion.fromInt(null), EncryptionVersion.none);
      expect(EncryptionVersion.fromInt(0), EncryptionVersion.none);
      expect(EncryptionVersion.none.isEncrypted, isFalse);
    });

    test('an unknown version does not claim encryption', () {
      expect(EncryptionVersion.fromInt(99), EncryptionVersion.none);
      expect(EncryptionVersion.fromInt(99).isEncrypted, isFalse);
    });
  });
}
