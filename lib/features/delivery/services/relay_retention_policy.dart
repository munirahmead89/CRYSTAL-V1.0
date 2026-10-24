import 'dart:convert';

import '../domain/message_lifecycle.dart';

/// When a relay payload becomes eligible for removal from the server.
///
/// This is a client-side *mirror* of the server-side rule in
/// `purge_relay_payloads`, not the enforcement point. The server decides what it
/// deletes; this exists so the app can explain the policy in its settings UI
/// and so a future client-side feature (a "server no longer holds this" hint)
/// does not have to re-derive it.
///
/// **The policy is WhatsApp-like:** a payload becomes eligible only after every
/// active, acknowledgement-required device of the recipient has confirmed
/// durable storage, and only after a grace period has elapsed since that last
/// confirmation.
///
/// ## What this does and does not promise
///
/// A device acknowledgement is evidence of a successful local database commit.
/// It is **not** a guarantee of permanent user-owned storage. If a recipient
/// clears app data after acknowledging, and the grace period has already
/// elapsed, the server copy is gone and recovery is impossible. Durability
/// beyond acknowledgement requires an encrypted client-side backup, which this
/// project does not implement. Do not describe the relay model as a backup.
class RelayRetentionPolicy {
  const RelayRetentionPolicy({
    this.graceSeconds = defaultGraceSeconds,
    this.requireAllDevices = true,
    this.tombstoneRetentionDays = defaultTombstoneDays,
    this.cleanupBatchSize = 500,
  });

  /// Fifteen minutes.
  ///
  /// Long enough for the sender's Realtime `UPDATE` to reach every online
  /// device and for a late-syncing device to fetch the message before the
  /// payload it needs disappears underneath it.
  static const int defaultGraceSeconds = 900;

  static const int defaultTombstoneDays = 30;

  /// Grounded in the SQL default in `relay_config`, so a client and a fresh
  /// database agree about the policy.
  final int graceSeconds;

  /// When true, cleanup waits for every active `ack_required` device of the
  /// recipient. When false, one device is enough.
  final bool requireAllDevices;

  /// How long a tombstone outlives the payload it protects.
  ///
  /// Must exceed the longest plausible offline window. Too short and a device
  /// that was offline long enough could re-fetch a deleted message from an
  /// in-between replica and resurrect it.
  final int tombstoneRetentionDays;

  final int cleanupBatchSize;

  /// True when a delivered message has been eligible long enough to purge.
  ///
  /// Purely a function of the last acknowledgement timestamp, so it is
  /// testable without a server.
  bool isGraceElapsed(DateTime lastAcknowledgedAt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    return reference.difference(lastAcknowledgedAt).inSeconds >= graceSeconds;
  }

  /// The count of devices still owing an acknowledgement.
  ///
  /// Zero means every required device has confirmed. Computed from the set of
  /// registered devices and the set of devices that have acknowledged, so the
  /// answer is "is there any required device that has not confirmed", which is
  /// the same predicate the SQL uses.
  int outstandingDeviceAcks({
    required Iterable<String> requiredDeviceIds,
    required Iterable<String> acknowledgedDeviceIds,
  }) {
    final acknowledged = acknowledgedDeviceIds.toSet();
    return requiredDeviceIds.where((id) => !acknowledged.contains(id)).length;
  }

  /// True when the message may be cleaned up.
  ///
  /// [acknowledgedDeviceIds] must contain only devices whose acknowledgement
  /// was actually recorded — an ack that was merely *sent* does not count, and
  /// neither does an ack that the server rejected.
  bool isEligibleForCleanup({
    required RetentionState retention,
    required bool deleted,
    required DateTime createdAt,
    required Iterable<String> requiredDeviceIds,
    required Iterable<String> acknowledgedDeviceIds,
    DateTime? lastAcknowledgedAt,
    DateTime? now,
  }) {
    // A deleted message was already emptied by `delete_message`; the sweeper
    // has nothing to do.
    if (deleted) return false;
    if (retention != RetentionState.retained) return false;
    if (outstandingDeviceAcks(
          requiredDeviceIds: requiredDeviceIds,
          acknowledgedDeviceIds: acknowledgedDeviceIds,
        ) >
        0) {
      return false;
    }

    final last = lastAcknowledgedAt ?? createdAt;
    return isGraceElapsed(last, now: now);
  }

  Map<String, dynamic> toJson() => {
    'grace_seconds': graceSeconds,
    'require_all_devices': requireAllDevices,
    'tombstone_retention_days': tombstoneRetentionDays,
    'cleanup_batch_size': cleanupBatchSize,
    'policy_version': 1,
  };

  /// Reads a policy from server configuration, falling back to the defaults for
  /// anything missing or malformed.
  ///
  /// A server that reports a nonsense grace period must not be able to make the
  /// app claim a false guarantee, so out-of-range values are replaced rather
  /// than trusted.
  factory RelayRetentionPolicy.fromServerJson(Map<String, dynamic>? json) {
    if (json == null) return const RelayRetentionPolicy();
    final grace = (json['cleanup_grace_seconds'] as num?)?.toInt();
    final all = json['require_all_devices'];
    final tombstoneDays = (json['tombstone_retention_days'] as num?)?.toInt();
    final batch = (json['cleanup_batch_size'] as num?)?.toInt();
    return RelayRetentionPolicy(
      graceSeconds: (grace != null && grace >= 0 && grace <= 2592000)
          ? grace
          : defaultGraceSeconds,
      requireAllDevices: all is bool ? all : true,
      tombstoneRetentionDays:
          (tombstoneDays != null && tombstoneDays > 0 && tombstoneDays <= 3650)
          ? tombstoneDays
          : defaultTombstoneDays,
      cleanupBatchSize: (batch != null && batch > 0 && batch <= 10000)
          ? batch
          : 500,
    );
  }

  static RelayRetentionPolicy decode(String? raw) {
    if (raw == null || raw.isEmpty) return const RelayRetentionPolicy();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const RelayRetentionPolicy();
      return RelayRetentionPolicy.fromServerJson(decoded);
    } catch (_) {
      return const RelayRetentionPolicy();
    }
  }

  String encode() => jsonEncode(toJson());

  /// Human-readable summary for the settings screen.
  ///
  /// States the limit honestly rather than implying the server keeps a backup.
  String describe() => requireAllDevices
      ? 'Message copies are removed from the server once every one of your '
            'devices has received them and $graceSeconds seconds have passed. '
            'Your own chat history stays on your devices. If you clear app data '
            'after a message arrives, that copy cannot be recovered.'
      : 'Message copies are removed from the server once one of your devices '
            'has received them and $graceSeconds seconds have passed. Your own '
            'chat history stays on your devices. If you clear app data after a '
            'message arrives, that copy cannot be recovered.';
}
