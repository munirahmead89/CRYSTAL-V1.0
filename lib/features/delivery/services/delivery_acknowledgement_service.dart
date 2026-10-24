import 'dart:async';

import '../../../core/database/local_store.dart';
import '../domain/message_lifecycle.dart';
import '../domain/relay_envelope.dart';
import '../domain/relay_failure.dart';
import '../domain/repositories/relay_repository.dart';

/// Result of one acknowledgement flush.
class AckFlushResult {
  const AckFlushResult({
    this.sent = 0,
    this.confirmed = 0,
    this.failed = 0,
    this.skipped = false,
  });

  /// Acknowledgements attempted.
  final int sent;

  /// Acknowledgements the relay confirmed.
  final int confirmed;

  /// Acknowledgements the relay rejected outright. These stay in the ledger
  /// and are retried, because a rejection is usually "try again" (a device the
  /// server has not registered yet) rather than "never".
  final int failed;

  /// True when the flush did not run at all, e.g. offline.
  final bool skipped;

  bool get hasPending => failed > 0;

  AckFlushResult merge(AckFlushResult other) => AckFlushResult(
    sent: sent + other.sent,
    confirmed: confirmed + other.confirmed,
    failed: failed + other.failed,
    skipped: skipped && other.skipped,
  );
}

/// Delivers the acknowledgements this device owes the relay.
///
/// The whole point of this class is that it is driven from a durable ledger in
/// SQLite rather than from whatever happened to be in memory. The ordering it
/// guarantees is the one the design requires:
///
///   1. the receiving device commits the message to its own database
///      ([LocalStore.commitIncomingMessage] writes a ledger row with
///      `reported = false` inside the same transaction);
///   2. this service notices the unreported row and sends it;
///   3. the relay records it idempotently;
///   4. only then is the ledger row flipped to `reported = true`.
///
/// Every interruption is recoverable:
/// * crash between 1 and 2 — the ledger row survives, the next flush sends it;
/// * lost response at 3 — the row is still unreported, so it is replayed, and
///   the server's unique constraint makes the replay a no-op;
/// * server says "unknown device" — the row stays unreported and backs off.
///
/// A delivery receipt is therefore never claimed because a socket opened, a
/// push arrived, or a Realtime event fired.
class DeliveryAcknowledgementService {
  DeliveryAcknowledgementService({
    required this.store,
    required this.repository,
    required this.deviceId,
    this.isOnline,
    this.onError,
  });

  final LocalStore store;
  final RelayRepository repository;

  /// The registered device id the relay validates ownership against.
  ///
  /// A client-supplied id is a claim, not proof of identity: the server checks
  /// that the row it names belongs to the authenticated user and is not
  /// revoked. Passing an empty id disables acknowledgement rather than sending
  /// an unverifiable one.
  final String deviceId;

  /// Consulted before any network work. Defaults to always-online so callers
  /// that do not track connectivity behave predictably.
  final bool Function()? isOnline;

  final void Function(Object error, StackTrace stack)? onError;

  /// Server-side per-call ceiling. One flush cannot exceed it.
  static const int batchSize = 100;

  bool _flushing = false;

  /// Collapses concurrent callers into one in-flight pass plus one follow-up,
  /// so a burst of realtime events cannot stack up identical work.
  bool _rerunRequested = false;

  /// Records that an incoming message is now stored locally and awaits an
  /// acknowledgement.
  ///
  /// Called from the commit path, not from a UI callback, so it cannot be
  /// skipped by a screen being closed.
  Future<void> recordPendingDeliveryAck(String messageId) {
    return store.recordPendingAck(messageId, AckKind.delivered);
  }

  /// Sends every acknowledgement this device still owes.
  Future<AckFlushResult> flushPending() async {
    if (_flushing) {
      _rerunRequested = true;
      return const AckFlushResult(skipped: true);
    }
    if (deviceId.isEmpty) return const AckFlushResult(skipped: true);
    if (isOnline?.call() == false) return const AckFlushResult(skipped: true);

    _flushing = true;
    var total = const AckFlushResult();
    try {
      do {
        _rerunRequested = false;
        total = total.merge(await _flushOnce());
      } while (_rerunRequested);
      return total;
    } catch (error, stack) {
      // A flush that throws must not lose the ledger rows: they are already
      // committed, so the next pass picks them up.
      onError?.call(error, stack);
      return total;
    } finally {
      _flushing = false;
    }
  }

  Future<AckFlushResult> _flushOnce() async {
    final pending = await store.pendingAcks(limit: batchSize);
    if (pending.isEmpty) return const AckFlushResult();

    final byKind = <AckKind, List<String>>{};
    for (final ack in pending) {
      byKind.putIfAbsent(ack.kind, () => <String>[]).add(ack.messageId);
    }

    var sent = 0;
    var confirmed = 0;
    var failed = 0;

    for (final entry in byKind.entries) {
      final ids = entry.value;
      if (entry.key != AckKind.delivered) {
        // Read receipts are a separate, user-visible decision and are sent by
        // the chat screen, not inferred from storage. Anything else that
        // reaches this ledger is stored but not auto-sent, because
        // auto-sending a read receipt would be a lie about user intent.
        continue;
      }

      try {
        final result = await repository.acknowledgeDelivered(
          messageIds: ids,
          deviceId: deviceId,
        );
        sent += ids.length;
        confirmed += result.accepted;

        if (result.accepted > 0) {
          // The server confirmed these; flipping them is safe even if some
          // were rejected, because a replay is idempotent.
          await store.markAcksReported(
            ids.take(result.accepted).toList(),
            AckKind.delivered,
          );
        }
        failed += (ids.length - result.accepted).clamp(0, ids.length);
      } catch (error, stack) {
        onError?.call(error, stack);
        sent += ids.length;
        failed += ids.length;

        // An authentication failure is not going to fix itself on the next
        // 30-second tick, so stop immediately rather than hammering.
        if (error is RelayException && !error.isRetryable) break;
      }
    }

    return AckFlushResult(sent: sent, confirmed: confirmed, failed: failed);
  }

  /// Marks a read receipt as owed, to be sent by [markRead].
  Future<void> recordPendingReadAck(String messageId) {
    return store.recordPendingAck(messageId, AckKind.read);
  }

  /// Sends a read receipt for the messages actually on screen.
  ///
  /// Separate from [flushPending] on purpose. A read receipt asserts a human
  /// saw a message, so it must be tied to a visible screen and to the
  /// sender's read-receipt preference — never to "the app started" or to "a
  /// sync happened in the background".
  Future<RelayReadResult> markRead({
    required String conversationId,
    String? upToMessageId,
  }) async {
    if (deviceId.isEmpty) return const RelayReadResult();
    if (isOnline?.call() == false) return const RelayReadResult();

    try {
      final result = await repository.markRead(
        conversationId: conversationId,
        deviceId: deviceId,
        upToMessageId: upToMessageId,
      );
      if (result.marked > 0) {
        // The ledger's read rows are not replayed (a read receipt is not
        // re-sent), so they are simply marked reported.
        final pending = await store.pendingAcks(limit: batchSize);
        await store.markAcksReported(
          pending
              .where((a) => a.kind == AckKind.read)
              .map((a) => a.messageId)
              .toList(),
          AckKind.read,
        );
      }
      return result;
    } catch (error, stack) {
      onError?.call(error, stack);
      return const RelayReadResult();
    }
  }

  /// Housekeeping. Reported rows are only useful while the relay might still
  /// be asked to re-derive state from them.
  Future<void> prune() => store.pruneAckLedger();
}
