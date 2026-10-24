import 'dart:math' as math;

/// Which way bytes are moving.
enum TransferDirection { upload, download }

/// Estimates transfer speed so the UI can show a meaningful ETA.
///
/// A single instantaneous sample is far too noisy on a mobile link: one
/// stalled part reads as "0 B/s" and implies an infinite wait, while one fast
/// burst implies a wildly optimistic finish. This smooths throughput with an
/// exponential moving average weighted toward recent samples, which is what
/// makes the countdown behave like the one users expect from a download dialog.
class TransferSpeedEstimator {
  TransferSpeedEstimator({this.halfLife = const Duration(seconds: 3)});

  /// How quickly old samples stop influencing the estimate.
  final Duration halfLife;

  int _lastBytes = 0;
  DateTime? _lastAt;
  double _bytesPerSecond = 0;

  double get bytesPerSecond => _bytesPerSecond;

  /// Feeds a new sample and returns the smoothed throughput in bytes/second.
  double update(int totalBytes, DateTime at) {
    final previousAt = _lastAt;
    final previousBytes = _lastBytes;
    _lastAt = at;
    _lastBytes = totalBytes;

    if (previousAt == null) return _bytesPerSecond;

    final elapsedMicros = at
        .difference(previousAt)
        .inMicroseconds
        .clamp(1, 1 << 62);
    final deltaBytes = totalBytes - previousBytes;
    if (deltaBytes <= 0) {
      // A stalled or repeated sample. Decay toward zero so the ETA grows
      // honestly instead of freezing at a stale optimistic number.
      _bytesPerSecond *= 0.75;
      if (_bytesPerSecond < 1) _bytesPerSecond = 0;
      return _bytesPerSecond;
    }

    final instantaneous = deltaBytes * 1000000 / elapsedMicros;

    // Alpha from the half-life: after `halfLife` an old sample retains half
    // its weight. Clamped so a single very slow or very fast sample cannot
    // dominate the whole estimate.
    final alpha = (1 - math.pow(0.5, elapsedMicros / halfLife.inMicroseconds))
        .toDouble()
        .clamp(0.05, 0.9);

    _bytesPerSecond = _bytesPerSecond == 0
        ? instantaneous
        : alpha * instantaneous + (1 - alpha) * _bytesPerSecond;

    if (_bytesPerSecond < 1) _bytesPerSecond = 0;
    return _bytesPerSecond;
  }

  void reset() {
    _lastBytes = 0;
    _lastAt = null;
    _bytesPerSecond = 0;
  }
}

/// A snapshot of one in-flight attachment transfer.
class TransferProgress {
  const TransferProgress({
    required this.id,
    required this.direction,
    required this.fileName,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.partsTransferred,
    required this.totalParts,
    required this.updatedAt,
    this.bytesPerSecond = 0,
    this.failed = false,
    this.done = false,
    this.fromCache = false,
  });

  /// Stable identity of the transfer (usually the upload id, or a
  /// `upload_id:download` pair).
  final String id;
  final TransferDirection direction;
  final String fileName;
  final int bytesTransferred;
  final int totalBytes;
  final int partsTransferred;
  final int totalParts;
  final DateTime updatedAt;
  final double bytesPerSecond;
  final bool failed;
  final bool done;
  final bool fromCache;

  bool get isActive => !done && !failed;

  /// 0.0 - 1.0, or `null` when the total size is not yet known so the UI can
  /// show an indeterminate bar instead of a fake 0%.
  double? get fraction => totalBytes <= 0
      ? null
      : (bytesTransferred / totalBytes).clamp(0.0, 1.0).toDouble();

  int get bytesRemaining =>
      (totalBytes - bytesTransferred).clamp(0, totalBytes).toInt();

  /// Time remaining, or `null` while the speed is not yet known well enough to
  /// make a promise. Returning null is deliberate: a countdown derived from one
  /// noisy sample is worse than an honest "calculating".
  Duration? get eta {
    if (done) return Duration.zero;
    final speed = bytesPerSecond;
    if (speed < 1 || bytesRemaining <= 0) return null;
    final seconds = bytesRemaining / speed;
    if (seconds.isInfinite || seconds.isNaN) return null;
    // Beyond ~1 day the estimate is noise; report null instead of "23h".
    if (seconds > 86400) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// "1.4 GB" / "312 KB" / "900 B"
  String get sizeLabel => formatBytes(totalBytes);

  /// "8.1 MB of 1.4 GB"
  String get transferredLabel =>
      '${formatBytes(bytesTransferred)} of ${formatBytes(totalBytes)}';

  /// "2.4 MB/s" or null when not yet measurable.
  String? get speedLabel {
    if (done) return null;
    if (bytesPerSecond < 1) return null;
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  /// "12s left" / "3m left" / null while unknown.
  String? get etaLabel {
    final remaining = eta;
    if (remaining == null) return null;
    return '${formatDuration(remaining)} left';
  }

  /// Whole rounded percent, which is what the user actually reads.
  int get percent {
    final f = fraction;
    return f == null ? 0 : (f * 100).round();
  }

  String get percentLabel => '$percent%';

  String get directionLabel =>
      direction == TransferDirection.upload ? 'Sending' : 'Downloading';

  TransferProgress copyWith({
    int? bytesTransferred,
    int? totalBytes,
    int? partsTransferred,
    int? totalParts,
    DateTime? updatedAt,
    double? bytesPerSecond,
    bool? failed,
    bool? done,
    bool? fromCache,
  }) {
    return TransferProgress(
      id: id,
      direction: direction,
      fileName: fileName,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      partsTransferred: partsTransferred ?? this.partsTransferred,
      totalParts: totalParts ?? this.totalParts,
      updatedAt: updatedAt ?? this.updatedAt,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      failed: failed ?? this.failed,
      done: done ?? this.done,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

/// Human-readable byte size using decimal units, matching how phone storage
/// and app stores report sizes (kB/MB/GB, not KiB/MiB/GiB).
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  const units = ['kB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }
  final decimals = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}

/// Compact duration for countdowns: "8s", "2m 05s", "1h 12m".
String formatDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds}s';
  if (d.inMinutes < 60) {
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}m $seconds s';
  }
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours}h $minutes m';
}

/// Fractional bytes left in the current part, for a sub-part progress bar.
double partFraction({
  required int bytesTransferred,
  required int totalBytes,
  required int partBytes,
}) {
  if (totalBytes <= 0 || partBytes <= 0) return 0;
  final inPart = bytesTransferred % partBytes;
  return (inPart / partBytes).clamp(0.0, 1.0).toDouble();
}
