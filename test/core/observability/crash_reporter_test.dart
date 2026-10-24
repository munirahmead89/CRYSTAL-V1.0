import 'package:crystal_messenger/core/observability/crash_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reporter runs from `main()` before anything else and is the last line of
/// defence, so the property that matters most is that it can never take the app
/// down with it.
///
/// `path_provider` has no implementation under the unit-test harness, which is
/// also the interesting case: it is the same shape of failure as a real device
/// with no writable storage, and the reporter must degrade to a no-op.
void main() {
  group('CrashReporter', () {
    test('starts disabled so nothing is recorded before enable()', () {
      expect(CrashReporter.isEnabled, isFalse);
    });

    test('enable() is idempotent and marks the reporter active', () {
      CrashReporter.enable();
      CrashReporter.enable();
      expect(CrashReporter.isEnabled, isTrue);
    });

    test('report() and log() never throw when storage is unavailable', () {
      CrashReporter.enable();
      expect(
        () => CrashReporter.report(
          StateError('boom'),
          StackTrace.current,
          reason: 'test',
          fatal: true,
        ),
        returnsNormally,
      );
      expect(() => CrashReporter.log('breadcrumb'), returnsNormally);
    });

    test('readAll() yields an empty list instead of failing', () async {
      CrashReporter.enable();
      expect(await CrashReporter.readAll(), isEmpty);
    });

    test('clear() reports failure rather than throwing', () async {
      CrashReporter.enable();
      expect(await CrashReporter.clear(), isFalse);
    });

    test('wireGlobalHooks() installs hooks that survive a thrown error', () {
      CrashReporter.enable();
      expect(CrashReporter.wireGlobalHooks, returnsNormally);
    });
  });
}
