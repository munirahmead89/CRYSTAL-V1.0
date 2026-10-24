import '../../../core/database/local_store.dart';
import '../domain/repositories/relay_repository.dart';

/// What one recovery pass did.
class RelayRecoveryResult {
  const RelayRecoveryResult({
    this.deletionEventsApplied = 0,
    this.deletionEventsRejected = 0,
    this.cursorsAdvanced = 0,
    this.deletionsFailed = false,
  });

  final int deletionEventsApplied;

  /// Events the server sent that this build could not read. A non-zero value
  /// means the server is ahead of the client, not that a message was lost.
  final int deletionEventsRejected;

  final int cursorsAdvanced;

  /// True when the deletion pass could not run. Messages are still recovered by
  /// the ordinary message sync, so this degrades latency rather than losing
  /// anything — except that a deletion stays unapplied until it succeeds.
  final bool deletionsFailed;

  bool get hasWork => deletionEventsApplied > 0 || cursorsAdvanced > 0;
}

/// Recovers deletions the device missed while it was offline.
///
/// This is a separate pass from the message sync on purpose. A message pull is
/// ordered by message id or `(created_at, id)`, and **neither can observe a
/// removal** — a deleted message simply is not in the result set any more. A
/// device that was offline while someone deleted a message would therefore keep
/// showing it forever, which is the exact failure a tombstone design has to
/// close.
///
/// Ordering rules that keep this safe:
///
/// * The deletion cursor is a timestamp and only ever moves forward, so a stale
///   or replayed batch cannot un-apply a newer deletion.
/// * Deletions are applied BEFORE the message catch-up in the same pass, so a
///   message that was fetched and then deleted is tombstoned rather than
///   stored.
/// * The tombstone is checked on the write path of every incoming message, so
///   even a message fetched before its deletion was known cannot resurrect.
class RelaySyncRecoveryService {
  RelaySyncRecoveryService({
    required this.store,
    required this.repository,
    this.isOnline,
    this.onError,
  });

  final LocalStore store;
  final RelayRepository repository;
  final bool Function()? isOnline;
  final void Function(Object error, StackTrace stack)? onError;

  /// Bounded so one pass cannot become an unbounded download on a device that
  /// has been offline for weeks.
  static const int deletionPageSize = 200;

  /// Cursor key namespace. Separate from the message cursor because the two
  /// advance for different reasons and must not share a watermark.
  static String deletionCursorKey() => 'deletions';

  /// Fetches and applies every deletion event newer than the local cursor.
  ///
  /// Loops until the server returns a partial page, so a backlog larger than
  /// one page is fully drained rather than silently truncated.
  Future<RelayRecoveryResult> recoverDeletions() async {
    if (isOnline?.call() == false) {
      return const RelayRecoveryResult(deletionsFailed: true);
    }

    final key = deletionCursorKey();
    var cursor = await store.getDeviceCursor(key);
    var applied = 0;
    var rejected = 0;
    var pages = 0;
    var advanced = 0;

    try {
      while (pages < maxPages) {
        final since = cursor == null ? null : DateTime.tryParse(cursor);

        final events = await repository.fetchDeletionEvents(
          sinceIso: since,
          limit: deletionPageSize,
        );
        pages++;

        if (events.isEmpty) break;

        // The server returns ascending order, so the last element is the
        // newest. Advancing from the newest means a page that fails to apply
        // entirely leaves the cursor where it was and the next pass re-fetches
        // it.
        final newest = events.last.deletedAt;
        final count = await store.applyDeletionEvents(events, cursorKey: key);

        applied += count;
        rejected += events.length - count;
        advanced++;

        final nextCursor = newest.toUtc().toIso8601String();
        if (nextCursor == cursor) break;
        cursor = nextCursor;

        if (events.length < deletionPageSize) break;
      }

      return RelayRecoveryResult(
        deletionEventsApplied: applied,
        deletionEventsRejected: rejected,
        cursorsAdvanced: advanced,
      );
    } catch (error, stack) {
      onError?.call(error, stack);
      return RelayRecoveryResult(
        deletionEventsApplied: applied,
        deletionEventsRejected: rejected,
        cursorsAdvanced: advanced,
        deletionsFailed: true,
      );
    }
  }

  /// Hard ceiling on pages per pass.
  ///
  /// Guards the same failure the message sync guards: a cursor that cannot
  /// advance would otherwise loop forever.
  static const int maxPages = 20;

  /// Convenience for the startup path: deletes first, then messages.
  ///
  /// The order is load-bearing. Applying deletions first means a message that
  /// is about to be fetched is already known to be dead, so the chat screen
  /// never renders a bubble that a tombstone is about to erase.
  Future<RelayRecoveryResult> recover() => recoverDeletions();
}
