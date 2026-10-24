import 'package:crystal_messenger/core/media/transfer_progress.dart';
import 'package:crystal_messenger/core/media/transfer_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatting', () {
    test('byte sizes use decimal units like a phone does', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1000), '1.0 kB');
      expect(formatBytes(1500), '1.5 kB');
      expect(formatBytes(10000), '10 kB');
      expect(formatBytes(1500000), '1.5 MB');
      expect(formatBytes(1500000000), '1.5 GB');
    });

    test('durations read as a countdown', () {
      expect(formatDuration(const Duration(seconds: 8)), '8s');
      expect(formatDuration(const Duration(seconds: 59)), '59s');
      expect(formatDuration(const Duration(minutes: 2, seconds: 5)), '2m 05 s');
      expect(formatDuration(const Duration(hours: 1, minutes: 12)), '1h 12 m');
    });
  });

  group('TransferProgress', () {
    TransferProgress build({
      required int transferred,
      required int total,
      double speed = 0,
      bool done = false,
    }) {
      return TransferProgress(
        id: 't1',
        direction: TransferDirection.upload,
        fileName: 'clip.mp4',
        bytesTransferred: transferred,
        totalBytes: total,
        partsTransferred: 1,
        totalParts: 4,
        updatedAt: DateTime(2026),
        bytesPerSecond: speed,
        done: done,
      );
    }

    test('fraction and percent track bytes, not parts', () {
      final p = build(transferred: 250, total: 1000);
      expect(p.fraction, 0.25);
      expect(p.percent, 25);
      expect(p.percentLabel, '25%');
    });

    test('fraction is null (indeterminate) when the total is unknown', () {
      // An indeterminate bar is honest; a bar pinned at 0% looks broken.
      expect(build(transferred: 0, total: 0).fraction, isNull);
      expect(build(transferred: 10, total: 0).percent, 0);
    });

    test('eta is null until the speed is meaningful', () {
      expect(build(transferred: 0, total: 1000).eta, isNull);
      expect(build(transferred: 0, total: 1000, speed: 0.4).eta, isNull);
    });

    test('eta is the remaining time at the observed speed', () {
      // 1 MB of a 4 MB file at 1 MB/s = 3 s left.
      final p = build(transferred: 1000000, total: 4000000, speed: 1000000);
      expect(p.eta, const Duration(seconds: 3));
      expect(p.etaLabel, '3s left');
    });

    test('eta is zero only once the transfer is flagged done', () {
      final done = build(
        transferred: 4000000,
        total: 4000000,
        speed: 1000000,
        done: true,
      );
      expect(done.eta, Duration.zero);
      expect(done.isActive, isFalse);

      // Not yet flagged, but nothing left to move: no promise is made.
      final finishing = build(
        transferred: 4000000,
        total: 4000000,
        speed: 1000000,
      );
      expect(finishing.eta, isNull);
    });

    test('eta is null for an absurdly long prediction rather than lying', () {
      // 1 byte/s over 1 GB would be ~11 days; reporting "1 B/s, 111 days left"
      // is noise, so the UI shows "calculating" instead.
      final p = build(transferred: 0, total: 1000000000, speed: 1);
      expect(p.eta, isNull);
    });

    test('labels read the way a user expects', () {
      final p = build(transferred: 1500000, total: 4000000, speed: 250000);
      expect(p.sizeLabel, '4.0 MB');
      expect(p.transferredLabel, '1.5 MB of 4.0 MB');
      expect(p.speedLabel, '250 kB/s');
      expect(p.directionLabel, 'Sending');
    });
  });

  group('TransferSpeedEstimator', () {
    test('a single sample cannot produce a speed', () {
      final e = TransferSpeedEstimator();
      final t0 = DateTime(2026);
      e.update(1000, t0);
      expect(e.bytesPerSecond, 0, reason: 'no interval has elapsed yet');
    });

    test('consecutive samples converge on the real throughput', () {
      final e = TransferSpeedEstimator();
      final t0 = DateTime(2026);
      e.update(0, t0);
      // 1 MB per second, sampled every 100 ms.
      for (var i = 1; i <= 20; i++) {
        e.update(i * 100000, t0.add(Duration(milliseconds: 100 * i)));
      }
      expect(e.bytesPerSecond, closeTo(1000000, 100000));
    });

    test('a stall decays the estimate instead of freezing it', () {
      // Regression guard: with no decay, one fast sample would keep promising
      // an imminent finish while the network was actually dead.
      final e = TransferSpeedEstimator();
      final t0 = DateTime(2026);
      e.update(0, t0);
      for (var i = 1; i <= 5; i++) {
        e.update(i * 1000000, t0.add(Duration(seconds: i)));
      }
      final busy = e.bytesPerSecond;
      expect(busy, greaterThan(0));

      // Same byte count again: no progress.
      for (var i = 6; i <= 12; i++) {
        e.update(5000000, t0.add(Duration(seconds: i)));
      }
      expect(e.bytesPerSecond, lessThan(busy));
    });

    test('reset clears history', () {
      final e = TransferSpeedEstimator();
      final t0 = DateTime(2026);
      e.update(0, t0);
      e.update(1000000, t0.add(const Duration(seconds: 1)));
      expect(e.bytesPerSecond, greaterThan(0));
      e.reset();
      expect(e.bytesPerSecond, 0);
    });
  });

  group('TransferTracker', () {
    late TransferTracker tracker;

    setUp(() => tracker = TransferTracker());
    tearDown(() => tracker.dispose());

    test('tracks a transfer from start to finish', () {
      final id = tracker.start(
        direction: TransferDirection.download,
        fileName: 'movie.mp4',
        totalBytes: 2000,
      );
      expect(tracker.activeCount, 1);
      expect(tracker.hasActive, isTrue);

      tracker.report(id, bytesTransferred: 1000);
      expect(tracker.byId(id)!.bytesTransferred, 1000);
      expect(tracker.byId(id)!.fraction, 0.5);
      expect(tracker.byId(id)!.isActive, isTrue);

      tracker.report(id, bytesTransferred: 2000, done: true);
      expect(tracker.byId(id)!.isActive, isFalse);
      expect(tracker.byId(id)!.done, isTrue);
      expect(tracker.hasActive, isFalse);
    });

    test('a failed transfer is not reported as active', () {
      final id = tracker.start(
        direction: TransferDirection.upload,
        fileName: 'clip.mp4',
        totalBytes: 1000,
      );
      tracker.report(id, bytesTransferred: 400, failed: true);
      expect(tracker.byId(id)!.failed, isTrue);
      expect(tracker.byId(id)!.isActive, isFalse);
      expect(tracker.hasActive, isFalse);
    });

    test('uploads and downloads are listed together, newest first', () {
      final up = tracker.start(
        direction: TransferDirection.upload,
        fileName: 'a.mp4',
        totalBytes: 100,
      );
      final down = tracker.start(
        direction: TransferDirection.download,
        fileName: 'b.mp4',
        totalBytes: 100,
      );
      expect(tracker.transfers, hasLength(2));
      expect(tracker.transfers.first.id, down);
      expect(tracker.transfers.first.direction, TransferDirection.download);
      expect(tracker.transfers.last.id, up);
    });

    test('cancel removes the row immediately', () async {
      var cancelled = false;
      final id = tracker.start(
        direction: TransferDirection.upload,
        fileName: 'a.mp4',
        totalBytes: 100,
        onCancel: () async => cancelled = true,
      );
      await tracker.cancel(id);
      expect(cancelled, isTrue);
      expect(tracker.byId(id), isNull);
      expect(tracker.hasActive, isFalse);
    });

    test('clearFinished drops completed rows but keeps running ones', () {
      final done = tracker.start(
        direction: TransferDirection.upload,
        fileName: 'done.mp4',
        totalBytes: 100,
      );
      tracker.report(done, bytesTransferred: 100, done: true);
      final running = tracker.start(
        direction: TransferDirection.upload,
        fileName: 'running.mp4',
        totalBytes: 100,
      );

      tracker.clearFinished();
      expect(tracker.byId(done), isNull);
      expect(tracker.byId(running), isNotNull);
    });
  });
}
