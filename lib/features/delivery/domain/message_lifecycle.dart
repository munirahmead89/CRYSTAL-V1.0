/// Closed vocabulary for the message relay lifecycle.
///
/// Every state transition in the app goes through one of these enums. Raw
/// status strings are accepted at the decoding boundary (a server row, a
/// cached column written by an older build) and normalised immediately, so a
/// typo can never reach a comparison or a database write.
///
/// The enums here deliberately do NOT model "which devices have this message".
/// That is per-device data and lives in rows, not in a scalar.
library;

/// Where a message is in its journey from composition to durable delivery.
///
/// This is deliberately NOT the same thing as [AckKind] and NOT the same thing
/// as the recipient-facing receipt state. A single mutable "status" column
/// cannot represent three devices disagreeing about delivery, which is why
/// per-device acknowledgement rows exist on the server and why this enum only
/// describes what THIS device knows.
///
/// Ordering is meaningful: [failed] and [deleted] are terminal for the send
/// path, [pending] is the only state in which an upload has not been
/// attempted, and [delivered] is the first state backed by evidence from
/// another device.
enum DeliveryState {
  /// Written to SQLite, waiting for a usable network. No upload attempted.
  pending,

  /// The server durably accepted the message and returned an authoritative
  /// status. This is the only transition that requires a server response.
  sent,

  /// A recipient device committed this message to its own durable storage and
  /// acknowledged it. Never inferred from a socket, a push or a Realtime event.
  delivered,

  /// A user explicitly read the message in the chat screen, subject to the
  /// read-receipt privacy setting.
  read,

  /// The retry budget was exhausted. The outbox row is retained, so this is
  /// a UI state rather than a permanent outcome.
  failed,

  /// Removed from view. [DeliveryState.deleted] is terminal for the send path.
  deleted;

  /// True when no further upload attempt should be made automatically.
  bool get isTerminal => this == deleted;

  /// True while the message still needs to reach the server.
  bool get awaitsUpload => this == pending || this == failed;

  /// Parses a persisted or wire value, falling back to [fallback] for an
  /// unknown string.
  ///
  /// A malformed or newer-than-known value must not throw: a row cached by a
  /// future build, or corrupted by a partial write, has to render as something
  /// rather than crash the chat screen.
  static DeliveryState fromString(String? value, {DeliveryState? fallback}) {
    if (value == null || value.isEmpty) return fallback ?? DeliveryState.sent;
    for (final state in DeliveryState.values) {
      if (state.name == value) return state;
    }
    return fallback ?? DeliveryState.sent;
  }
}

/// Which of the two receipt concepts an acknowledgement represents.
///
/// A delivery receipt and a read receipt are separate concepts and are
/// recorded separately on both sides. Collapsing them is what produces the
/// "marked as read the moment it arrived" behaviour the requirements call out.
enum AckKind {
  /// The recipient device durably committed the message. Recorded only after
  /// the local transaction commits.
  delivered,

  /// A person read the message. Recorded only when the message was actually
  /// on screen and the sender permits read receipts.
  read;

  /// Parses a wire value, defaulting to [delivered] because a delivery ack is
  /// the weaker and therefore safer claim to make.
  static AckKind fromString(String? value, {AckKind? fallback}) {
    if (value == null || value.isEmpty) return fallback ?? AckKind.delivered;
    for (final kind in AckKind.values) {
      if (kind.name == value) return kind;
    }
    return fallback ?? AckKind.delivered;
  }
}

/// Server-side lifecycle of a relay payload.
///
/// The payload is retained after the message row itself survives: the row is
/// the deduplication record that lets a lost-response retry resolve to
/// "already sent" instead of creating a second message.
enum RetentionState {
  /// Payload is present and still deliverable.
  retained,

  /// Payload has been nulled. The row remains as a tombstone + dedupe marker.
  payloadPurged;

  /// Wire/persisted values from Postgres use the snake_case spelling.
  static RetentionState fromString(String? value, {RetentionState? fallback}) {
    switch (value) {
      case 'retained':
        return RetentionState.retained;
      case 'payload_purged':
      case 'payloadPurged':
        return RetentionState.payloadPurged;
      default:
        return fallback ?? RetentionState.retained;
    }
  }

  /// The Postgres spelling, so a persisted value round-trips.
  String get wireValue =>
      this == RetentionState.payloadPurged ? 'payload_purged' : 'retained';
}

/// What a deletion request is scoped to.
///
/// The two are deliberately different mechanisms. "For me" is a local-only
/// operation with no server contact at all, because it must work with no
/// network; "for everyone" is a server-authorized event that other devices
/// have to learn about.
enum DeletionScope {
  /// Remove from this device only. Recorded as a local tombstone so a later
  /// sync cannot restore it. Never touches the server.
  me,

  /// Remove for every participant. Recorded as a durable server tombstone and
  /// propagated to other devices through the deletion cursor.
  everyone;

  static DeletionScope fromString(String? value, {DeletionScope? fallback}) {
    if (value == null || value.isEmpty) {
      return fallback ?? DeletionScope.everyone;
    }
    for (final scope in DeletionScope.values) {
      if (scope.name == value) return scope;
    }
    return fallback ?? DeletionScope.everyone;
  }
}

/// Message types the relay will accept.
///
/// Enforced server-side in `send_message`. Kept in sync with the Postgres
/// allowlist so a client-side check is never the only one.
enum RelayMessageType {
  text('text'),
  image('image'),
  file('file'),
  voice('voice'),
  video('video'),
  system('system');

  const RelayMessageType(this.wireValue);

  final String wireValue;

  /// The allowlist membership test, mirroring the SQL `= ANY(...)` check.
  ///
  /// Strict: null for anything not on the allowlist, including null and empty.
  /// [parse] is the lenient variant that supplies a fallback, so the two have
  /// clearly different jobs — "can I render this?" versus "what should I show?".
  static RelayMessageType? tryParse(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final type in RelayMessageType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return null;
  }

  static RelayMessageType parse(String? value) =>
      tryParse(value) ?? RelayMessageType.text;
}

/// Version of the local database's message schema.
///
/// Stored per row so a message written by a newer build, or decoded by an
/// older one, is handled explicitly instead of by best-effort key lookups.
enum RelaySchemaVersion {
  /// The original single-table shape with no relay metadata.
  v1(1),

  /// Per-device delivery state, tombstones and account scoping.
  v2(2);

  const RelaySchemaVersion(this.value);

  final int value;

  /// Highest version this build writes.
  static const RelaySchemaVersion current = RelaySchemaVersion.v2;

  /// Reads a stored version, clamping an unknown one to the newest known
  /// rather than throwing.
  static RelaySchemaVersion fromInt(int? value) {
    for (final version in RelaySchemaVersion.values) {
      if (version.value == value) return version;
    }
    return RelaySchemaVersion.current;
  }
}

/// Encryption state of a relay payload.
///
/// [none] is the honest value today: messages are stored server-side as
/// plaintext and protected by HTTPS plus row-level security, which is *not*
/// end-to-end encryption. Having the field typed and carried through the
/// protocol is what allows a future encryption phase to land without another
/// schema migration.
enum EncryptionVersion {
  /// Relay carries plaintext. Protected in transit and by RLS, not by E2EE.
  none(0),

  /// Reserved for a future documented encryption protocol.
  reserved(1);

  const EncryptionVersion(this.value);

  final int value;

  static EncryptionVersion fromInt(int? value) {
    if (value == null || value == 0) return EncryptionVersion.none;
    for (final version in EncryptionVersion.values) {
      if (version.value == value) return version;
    }
    return EncryptionVersion.none;
  }

  /// True only when the payload is actually opaque to the relay.
  bool get isEncrypted => this != EncryptionVersion.none;
}
