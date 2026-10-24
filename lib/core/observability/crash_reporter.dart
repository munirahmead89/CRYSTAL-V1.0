import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local, self-hosted crash and breadcrumb recorder.
///
/// ## Why this exists instead of Crashlytics
///
/// The build has no Firebase dependency: a `google-services.json` is not
/// checked in, so a Crashlytics wrapper compiled against the SDK is inert and
/// silently drops every record. A wrapper that looks configured but records
/// nothing is worse than none, because a crash that never gets reported is a
/// crash that gets "fixed" twice.
///
/// This writes instead. Every fatal and non-fatal error is appended to a
/// size-capped JSON-lines file in the app support directory, which survives app
/// restarts, so the record from the crash that killed the app is still on disk
/// the next time it launches. Breadcrumbs ([log]) are written into the same
/// stream, giving the preceding steps leading up to a crash.
///
/// ## Properties
///
/// - Never throws and never blocks. All I/O is fire-and-forget and failures are
///   swallowed: observability must not be able to take the app down.
/// - No PII is written. Only the error type, message, stack and the app's own
///   breadcrumbs, never message bodies, phone numbers or tokens.
/// - No network. Reports stay on the device. See [CrashReporter.readAll] for the
///   entry point a support/debug screen would use.
class CrashReporter {
  CrashReporter._();

  static bool _enabled = false;
  static File? _file;

  /// Hard cap on the on-disk report. Older lines are dropped from the front, so
  /// a crash loop cannot fill the user's storage.
  static const int maxBytes = 512 * 1024;

  /// Reads as "crash reporting is active", not "a remote service is watching".
  static bool get isEnabled => _enabled;

  /// Marks the reporter active. Idempotent.
  static void enable() {
    _enabled = true;
    unawaited(_resolveFile());
  }

  /// Routes uncaught Flutter and platform errors into [report].
  ///
  /// Unlike a pure sink, this deliberately still calls
  /// `FlutterError.presentError`: the previous Crashlytics-based version
  /// replaced `FlutterError.onError` outright, so once enabled the framework
  /// stopped printing *any* build-mode framework error to the console and only
  /// remote-recorded it. Both should happen.
  static void wireGlobalHooks() {
    if (!_enabled) return;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousOnError?.call(details);
      FlutterError.presentError(details);
      report(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'Flutter framework error',
        fatal: false,
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      report(error, stackTrace, reason: 'Uncaught platform error', fatal: true);
      return true;
    };
  }

  /// Records an error. [fatal] only annotates the record; this reporter never
  /// terminates the process itself.
  static void report(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    if (!_enabled) return;
    _append(<String, Object?>{
      'type': 'error',
      'reason': reason,
      'fatal': fatal,
      'error': error.runtimeType.toString(),
      'message': _truncate(error.toString()),
      'stack': _truncate(stackTrace.toString(), 4000),
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Records a breadcrumb.
  static void log(String message) {
    if (!_enabled) return;
    _append(<String, Object?>{
      'type': 'log',
      'message': _truncate(message, 500),
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Returns the buffered records, newest last. Intended for a debug/support
  /// screen; empty when the reporter was never enabled or the app is on a
  /// platform without a writable app-support directory (web).
  static Future<List<Map<String, Object?>>> readAll() async {
    final file = await _resolveFile();
    if (file == null) return const [];
    try {
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      return raw
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => jsonDecode(line))
          .whereType<Map<String, Object?>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Deletes buffered reports. Returns true when the file is gone.
  static Future<bool> clear() async {
    final file = await _resolveFile();
    if (file == null) return false;
    try {
      if (await file.exists()) await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- internals -----------------------------------------------------------

  /// Resolves the report file exactly once. Separate from [_writeQueue] because
  /// the two futures mean different things: this one yields a path, the other
  /// only signals that the previous append finished.
  static Future<File?>? _fileFuture;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<File?> _resolveFile() {
    if (_file != null) return Future<File?>.value(_file);
    return _fileFuture ??= _create();
  }

  static Future<File?> _create() async {
    try {
      // Unsupported on web, where path_provider has no implementation.
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, 'crash_reports.jsonl'));
      _file = file;
      return file;
    } catch (_) {
      _file = null;
      return null;
    }
  }

  /// Serialises writes. Concurrent errors (a cascade during teardown, several
  /// failing futures) would otherwise interleave partial lines and corrupt the
  /// file, so each append waits for the previous one.
  static void _append(Map<String, Object?> entry) {
    _writeQueue = _writeQueue.then((_) async {
      final file = await _resolveFile();
      if (file == null) return;
      try {
        await file.writeAsString(
          '${jsonEncode(entry)}\n',
          mode: FileMode.append,
          flush: true,
        );
        await _trim(file);
      } catch (_) {
        // Storage full, permission denied, web: never surface to the user.
      }
    });
  }

  /// Drops the oldest records once the file exceeds [maxBytes].
  static Future<void> _trim(File file) async {
    final length = await file.length();
    if (length <= maxBytes) return;

    final raw = await file.readAsString();
    final lines = raw.split('\n').where((line) => line.trim().isNotEmpty);
    // Keep the newest 75% so trimming is amortised rather than running on
    // every single append.
    final kept = lines.skip((lines.length * 0.25).floor()).toList();
    await file.writeAsString('${kept.join('\n')}\n', flush: true);
  }

  /// Collapses newlines so one record stays on one line and keeps the JSON
  /// Lines format parseable.
  static String _truncate(String value, [int max = 1000]) {
    final flat = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}…';
  }
}
