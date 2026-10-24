import 'dart:async';

import 'package:flutter/foundation.dart';

import 'transfer_progress.dart';

/// One row in the transfers list.
class ActiveTransfer {
  const ActiveTransfer({
    required this.id,
    required this.direction,
    required this.fileName,
    required this.progress,
    required this.sequence,
    this.onCancel,
  });

  final String id;
  final TransferDirection direction;
  final String fileName;
  final TransferProgress progress;

  /// Monotonic insertion counter.
  ///
  /// Two transfers started inside the same clock tick share an `updatedAt`
  /// (Windows' timer granularity is coarse), so sorting on time alone leaves
  /// the order between them undefined. The sequence breaks that tie and makes
  /// "newest first" actually true.
  final int sequence;

  /// Invoked when the user cancels; the engine is expected to abandon the
  /// in-flight part and clean up the partial session.
  final Future<void> Function()? onCancel;

  ActiveTransfer copyWith({TransferProgress? progress}) => ActiveTransfer(
    id: id,
    direction: direction,
    fileName: fileName,
    progress: progress ?? this.progress,
    sequence: sequence,
    onCancel: onCancel,
  );
}

/// Process-wide registry of in-flight uploads and downloads.
///
/// This is what gives the app a single, always-correct answer to "what is this
/// phone sending and receiving right now" — the same list WhatsApp shows while
/// a transfer runs. It is a [ChangeNotifier] rather than per-widget state so a
/// transfer started in the chat page stays visible in the transfers sheet after
/// the user navigates away.
///
/// Completed transfers are retained briefly so the user can see the result
/// ("Sent", "Saved") instead of a row vanishing mid-glance, then dropped.
class TransferTracker extends ChangeNotifier {
  TransferTracker();

  final Map<String, ActiveTransfer> _transfers = {};
  final Map<String, TransferSpeedEstimator> _estimators = {};

  /// How long a finished transfer lingers before being pruned.
  static const retention = Duration(seconds: 6);

  final Map<String, DateTime> _finishedAt = {};
  final List<Timer> _pruneTimers = [];
  int _sequence = 0;

  /// Newest-first, so the transfer the user just started is at the top.
  /// Ties on `updatedAt` are broken by insertion order so the list is stable
  /// and deterministic even when several transfers start in the same tick.
  List<ActiveTransfer> get transfers {
    final list = _transfers.values.toList()
      ..sort((a, b) {
        final byTime = b.progress.updatedAt.compareTo(a.progress.updatedAt);
        return byTime != 0 ? byTime : b.sequence.compareTo(a.sequence);
      });
    return List.unmodifiable(list);
  }

  List<ActiveTransfer> get active =>
      transfers.where((t) => t.progress.isActive).toList(growable: false);

  bool get hasActive => active.isNotEmpty;

  int get activeCount => active.length;

  TransferProgress? byId(String id) => _transfers[id]?.progress;

  /// The whole transfer row, including its cancel hook.
  ///
  /// [byId] is enough to draw a progress bar; a bubble needs more, because
  /// tapping its ring has to be able to stop the transfer rather than being a
  /// decoration.
  ActiveTransfer? entryById(String id) => _transfers[id];

  /// Registers a new transfer and returns its id.
  String start({
    required TransferDirection direction,
    required String fileName,
    required int totalBytes,
    String? id,
    int totalParts = 1,
    Future<void> Function()? onCancel,
  }) {
    final key =
        id ??
        '${direction.name}:${fileName.hashCode}:${DateTime.now().microsecondsSinceEpoch}';
    _finishedAt.remove(key);
    _estimators[key] = TransferSpeedEstimator();
    _transfers[key] = ActiveTransfer(
      id: key,
      direction: direction,
      fileName: fileName,
      sequence: _sequence++,
      progress: TransferProgress(
        id: key,
        direction: direction,
        fileName: fileName,
        bytesTransferred: 0,
        totalBytes: totalBytes,
        partsTransferred: 0,
        totalParts: totalParts,
        updatedAt: DateTime.now(),
      ),
      onCancel: onCancel,
    );
    notifyListeners();
    return key;
  }

  /// Records progress, folding it into the smoothed speed estimate.
  ///
  /// Notifications are coalesced to roughly one per frame's worth of time so a
  /// 350-part upload does not trigger 350 rebuilds of every listening widget.
  void report(
    String id, {
    required int bytesTransferred,
    int? totalBytes,
    int? partsTransferred,
    int? totalParts,
    bool failed = false,
    bool done = false,
    bool fromCache = false,
  }) {
    final existing = _transfers[id];
    if (existing == null) return;

    final now = DateTime.now();
    final speed = _estimators[id]?.update(bytesTransferred, now) ?? 0;

    _transfers[id] = existing.copyWith(
      progress: existing.progress.copyWith(
        bytesTransferred: bytesTransferred,
        totalBytes: totalBytes,
        partsTransferred: partsTransferred,
        totalParts: totalParts,
        updatedAt: now,
        bytesPerSecond: speed,
        failed: failed,
        done: done,
        fromCache: fromCache,
      ),
    );

    if (done || failed) {
      // Terminal states notify immediately: the widget showing this row must not
      // sit on a stale 93% while the row says "done".
      _cancelPendingNotify();
      _markFinished(id);
    } else {
      _scheduleNotify();
    }
  }

  /// Shortest gap between notifications.
  ///
  /// A 340 MB video is 57 parts, and each part reports twice (scheduled and
  /// completed). That is ~114 rebuilds of every listening surface - the
  /// transfers sheet, the chat bubble, the send banner - for a bar that only
  /// moves 114 times regardless. Ten a second is more than any screen can show.
  static const Duration _notifyInterval = Duration(milliseconds: 100);

  Timer? _notifyTimer;

  /// Guards the timer callback against a dispose that lands between the timer
  /// firing and `notifyListeners`. `dispose` also cancels the timer, but a
  /// callback already in flight would still run.
  bool _disposed = false;

  void _scheduleNotify() {
    if (_notifyTimer != null) return;
    _notifyTimer = Timer(_notifyInterval, () {
      _notifyTimer = null;
      if (_disposed) return;
      notifyListeners();
    });
  }

  void _cancelPendingNotify() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
  }

  void _markFinished(String id) {
    _finishedAt[id] = DateTime.now();
    notifyListeners();
    final timer = Timer(retention, () {
      _transfers.remove(id);
      _estimators.remove(id);
      _finishedAt.remove(id);
      notifyListeners();
    });
    _pruneTimers.add(timer);
  }

  /// Aborts a transfer and removes it immediately.
  Future<void> cancel(String id) async {
    final transfer = _transfers[id];
    if (transfer == null) return;
    try {
      await transfer.onCancel?.call();
    } catch (_) {
      // Cancellation is best-effort; the row still disappears.
    }
    _transfers.remove(id);
    _estimators.remove(id);
    _finishedAt.remove(id);
    notifyListeners();
  }

  /// Drops every finished row immediately (e.g. the user dismissed the sheet).
  void clearFinished() {
    var changed = false;
    for (final id in _finishedAt.keys.toList()) {
      if (_transfers[id]?.progress.isActive == false) {
        _transfers.remove(id);
        _estimators.remove(id);
        _finishedAt.remove(id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPendingNotify();
    for (final timer in _pruneTimers) {
      timer.cancel();
    }
    _pruneTimers.clear();
    super.dispose();
  }
}
